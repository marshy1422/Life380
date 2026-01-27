import Foundation
import CoreLocation
#if os(iOS)
import CoreMotion
#endif
import Combine
import SwiftUI
import os.log

// MARK: - Debug Logger

private let logger = Logger(subsystem: "com.life380.app", category: "PrecisionLocation")

/// Logging helper for geofencing and location events
/// Uses OSLog for production, adds console prints only in DEBUG
struct GeofenceLogger {
    static func logGeofenceAdd(_ identifier: String, coordinate: CLLocationCoordinate2D, radius: Double) {
        logger.info("GEOFENCE ADD: '\(identifier)' at (\(coordinate.latitude), \(coordinate.longitude)) radius=\(radius)m")
        #if DEBUG
        print("🔵 [GEOFENCE] ADD: '\(identifier)' radius=\(radius)m")
        #endif
    }

    static func logGeofenceRemove(_ identifier: String) {
        logger.info("GEOFENCE REMOVE: '\(identifier)'")
        #if DEBUG
        print("🔴 [GEOFENCE] REMOVE: '\(identifier)'")
        #endif
    }

    static func logGeofenceEntry(_ identifier: String) {
        logger.notice("GEOFENCE ENTRY: '\(identifier)'")
        #if DEBUG
        print("🟢 [GEOFENCE] ENTRY: '\(identifier)'")
        #endif
    }

    static func logGeofenceExit(_ identifier: String) {
        logger.notice("GEOFENCE EXIT: '\(identifier)'")
        #if DEBUG
        print("🟠 [GEOFENCE] EXIT: '\(identifier)'")
        #endif
    }

    static func logGeofenceSync(placesCount: Int, currentCount: Int) {
        logger.info("GEOFENCE SYNC: \(placesCount) places")
        #if DEBUG
        print("🔄 [GEOFENCE] SYNC: \(placesCount) places")
        #endif
    }

    static func logMonitoringStarted(_ identifier: String) {
        logger.info("GEOFENCE MONITORING STARTED: '\(identifier)'")
        #if DEBUG
        print("✅ [GEOFENCE] MONITORING: '\(identifier)'")
        #endif
    }

    static func logMonitoringFailed(_ identifier: String?, error: Error) {
        logger.error("GEOFENCE MONITORING FAILED: '\(identifier ?? "unknown")' - \(error.localizedDescription)")
        #if DEBUG
        print("❌ [GEOFENCE] FAILED: '\(identifier ?? "unknown")'")
        #endif
    }

    static func logLocationUpdate(lat: Double, lon: Double, accuracy: Double, source: String, accepted: Bool) {
        #if DEBUG
        // Only log in debug to avoid performance impact
        let status = accepted ? "✓" : "✗"
        print("📍 \(status) (\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))) ±\(Int(accuracy))m")
        #endif
    }

    static func logDistanceToGeofence(_ identifier: String, distance: Double, radius: Double) {
        #if DEBUG
        let inside = distance <= radius
        print("📏 \(identifier): \(Int(distance))m \(inside ? "INSIDE" : "OUTSIDE")")
        #endif
    }
}

// MARK: - Floor Level

struct FloorLevel {
    let level: Int
    let relativeAltitude: Double  // meters from starting point
    let pressure: Double?         // kPa
    let timestamp: Date

    var displayName: String {
        if level == 0 {
            return "Ground floor"
        } else if level > 0 {
            return "Floor \(level)"
        } else {
            return "Basement \(abs(level))"
        }
    }
}

// MARK: - Motion State

enum MotionState: String {
    case stationary = "stationary"
    case walking = "walking"
    case running = "running"
    case driving = "driving"
    case unknown = "unknown"

    var updateInterval: TimeInterval {
        switch self {
        case .stationary: return 30    // Update every 30s when still
        case .walking: return 10       // Update every 10s when walking
        case .running: return 5        // Update every 5s when running
        case .driving: return 3        // Update every 3s when driving
        case .unknown: return 10
        }
    }

    var accuracyThreshold: Double {
        switch self {
        case .stationary: return 50    // Accept 50m when stationary
        case .walking: return 30       // Need 30m when walking
        case .running: return 30
        case .driving: return 50       // Allow 50m when driving (GPS works well)
        case .unknown: return 40
        }
    }
}

// MARK: - Kalman Filter

/// Simple 1D Kalman filter for location smoothing
class KalmanFilter {
    private var estimate: Double = 0
    private var errorEstimate: Double = 1
    private var errorMeasurement: Double
    private var q: Double  // Process noise

    init(initialEstimate: Double = 0, measurementError: Double = 10, processNoise: Double = 0.1) {
        self.estimate = initialEstimate
        self.errorMeasurement = measurementError
        self.q = processNoise
    }

    func update(measurement: Double, measurementError: Double? = nil) -> Double {
        let currentMeasurementError = measurementError ?? errorMeasurement

        // Prediction update
        errorEstimate = errorEstimate + q

        // Measurement update
        let kalmanGain = errorEstimate / (errorEstimate + currentMeasurementError)
        estimate = estimate + kalmanGain * (measurement - estimate)
        errorEstimate = (1 - kalmanGain) * errorEstimate

        return estimate
    }

    func reset(to value: Double) {
        estimate = value
        errorEstimate = 1
    }
}

// MARK: - Location Smoother

/// Applies Kalman filtering to smooth location updates
class LocationSmoother {
    private var latFilter: KalmanFilter
    private var lonFilter: KalmanFilter
    private var isInitialized = false

    init() {
        latFilter = KalmanFilter(processNoise: 0.00001)  // Tuned for lat/lon scale
        lonFilter = KalmanFilter(processNoise: 0.00001)
    }

    func smooth(_ location: PrecisionLocation) -> PrecisionLocation {
        if !isInitialized {
            latFilter.reset(to: location.latitude)
            lonFilter.reset(to: location.longitude)
            isInitialized = true
            return location
        }

        // Use horizontal accuracy as measurement error (converted to approximate degrees)
        let accuracyInDegrees = location.horizontalAccuracy / 111000  // ~111km per degree

        let smoothedLat = latFilter.update(
            measurement: location.latitude,
            measurementError: accuracyInDegrees
        )
        let smoothedLon = lonFilter.update(
            measurement: location.longitude,
            measurementError: accuracyInDegrees
        )

        return PrecisionLocation(
            id: location.id,
            latitude: smoothedLat,
            longitude: smoothedLon,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            course: location.course,
            speed: location.speed,
            timestamp: location.timestamp,
            source: location.source,
            floor: location.floor
        )
    }

    func reset() {
        isInitialized = false
    }
}

// MARK: - Precision Location Manager

class PrecisionLocationManager: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var currentLocation: PrecisionLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var motionState: MotionState = .unknown
    @Published var isTracking: Bool = false
    @Published var locationError: Error?
    @Published var currentFloor: FloorLevel?
    @Published var isInBackground: Bool = false

    // Location history for patterns and debugging
    @Published var locationHistory: [PrecisionLocation] = []
    private let maxHistoryCount = 100

    // Geofencing
    @Published var monitoredRegions: [CLCircularRegion] = []
    private let maxGeofences = 20  // iOS limit

    // Place name lookup for notifications (placeId -> placeName)
    private var placeNames: [String: String] = [:]

    // MARK: - Configuration

    @AppStorage("precisionAccuracyThreshold") private var accuracyThresholdSetting: Double = 50
    @AppStorage("enableKalmanSmoothing") private var enableSmoothing: Bool = true
    @AppStorage("enableMotionAdaptive") private var enableMotionAdaptive: Bool = true

    var accuracyThreshold: Double {
        get { accuracyThresholdSetting }
        set { accuracyThresholdSetting = newValue }
    }

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    #if os(iOS)
    private let motionActivityManager = CMMotionActivityManager()
    private let altimeter = CMAltimeter()
    #endif
    private let smoother = LocationSmoother()

    private var lastAcceptedLocation: CLLocation?
    private var rejectedLocationCount = 0
    private var updateTimer: Timer?

    // Altimeter state
    private var referenceAltitude: Double?
    private var currentRelativeAltitude: Double = 0
    private let metersPerFloor: Double = 3.0  // Average floor height

    // Stats for debugging
    private(set) var totalLocationsReceived = 0
    private(set) var locationsAccepted = 0
    private(set) var locationsRejected = 0

    // MARK: - Initialization

    override init() {
        super.init()
        locationManager.delegate = self
        configureLocationManager()
    }

    private func configureLocationManager() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone  // Get all updates, we filter ourselves
        locationManager.pausesLocationUpdatesAutomatically = false

        #if os(iOS)
        if CMMotionActivityManager.isActivityAvailable() && enableMotionAdaptive {
            startMotionTracking()
        }
        #endif
    }

    // MARK: - Authorization

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    // MARK: - Tracking Control

    func startTracking() {
        guard !isTracking else { return }

        locationManager.startUpdatingLocation()
        isTracking = true

        #if os(iOS)
        if enableMotionAdaptive {
            startMotionTracking()
        }
        // Start altimeter for floor detection
        startAltimeterUpdates()
        #endif
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
        updateTimer?.invalidate()
        updateTimer = nil
        isTracking = false

        #if os(iOS)
        stopAltimeterUpdates()
        #endif
    }

    func enableBackgroundTracking() {
        locationManager.allowsBackgroundLocationUpdates = true
        #if os(iOS)
        locationManager.showsBackgroundLocationIndicator = true
        #endif
    }

    // MARK: - Motion Tracking

    #if os(iOS)
    private func startMotionTracking() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }

        motionActivityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity = activity else { return }
            self?.updateMotionState(from: activity)
        }
    }

    private func stopMotionTracking() {
        motionActivityManager.stopActivityUpdates()
    }

    private func updateMotionState(from activity: CMMotionActivity) {
        let newState: MotionState
        if activity.stationary {
            newState = .stationary
        } else if activity.running {
            newState = .running
        } else if activity.walking {
            newState = .walking
        } else if activity.automotive {
            newState = .driving
        } else {
            newState = .unknown
        }

        if newState != motionState {
            DispatchQueue.main.async {
                self.motionState = newState
                self.adaptToMotionState()
            }
        }
    }
    #endif

    private func adaptToMotionState() {
        guard enableMotionAdaptive else { return }

        // Adjust accuracy threshold based on motion
        // When stationary, we can be more lenient; when moving, we need precision
        switch motionState {
        case .stationary:
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        case .walking, .running:
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        case .driving:
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        case .unknown:
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        }
    }

    // MARK: - Background/Foreground Handling

    func handleAppBecameActive() {
        DispatchQueue.main.async {
            self.isInBackground = false
        }
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        if isTracking {
            locationManager.startUpdatingLocation()
        }
        // Stop significant location changes when in foreground
        locationManager.stopMonitoringSignificantLocationChanges()
    }

    func handleAppResignedActive() {
        DispatchQueue.main.async {
            self.isInBackground = true
        }
        guard authorizationStatus == .authorizedAlways else { return }

        // In background: stop continuous updates, use significant changes + geofences
        locationManager.stopUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
    }

    // MARK: - Altimeter / Floor Detection

    #if os(iOS)
    func startAltimeterUpdates() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            #if DEBUG
            logger.info("Altimeter not available on this device")
            #endif
            return
        }

        // Set reference altitude from current location if available
        if let altitude = currentLocation?.altitude {
            referenceAltitude = altitude
        }

        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }

            self.currentRelativeAltitude = data.relativeAltitude.doubleValue

            // Calculate floor level
            let floorLevel = self.calculateFloorLevel(
                relativeAltitude: data.relativeAltitude.doubleValue,
                pressure: data.pressure.doubleValue
            )

            DispatchQueue.main.async {
                self.currentFloor = floorLevel
            }
        }
    }

    func stopAltimeterUpdates() {
        altimeter.stopRelativeAltitudeUpdates()
    }

    private func calculateFloorLevel(relativeAltitude: Double, pressure: Double) -> FloorLevel {
        // Calculate floor based on relative altitude change
        // Positive altitude = going up, negative = going down
        let floorChange = Int(round(relativeAltitude / metersPerFloor))

        return FloorLevel(
            level: floorChange,
            relativeAltitude: relativeAltitude,
            pressure: pressure,
            timestamp: Date()
        )
    }

    /// Reset floor reference (call when user enters a known building)
    func resetFloorReference() {
        referenceAltitude = currentLocation?.altitude
        currentRelativeAltitude = 0
        DispatchQueue.main.async {
            self.currentFloor = FloorLevel(
                level: 0,
                relativeAltitude: 0,
                pressure: nil,
                timestamp: Date()
            )
        }
    }
    #endif

    // MARK: - Geofencing

    /// Add a geofence for a place (home, work, school, etc.)
    func addGeofence(identifier: String, coordinate: CLLocationCoordinate2D, radius: Double = 100) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            logger.error("Geofencing not available on this device")
            return
        }

        // Respect iOS limit
        guard monitoredRegions.count < maxGeofences else {
            logger.warning("Max geofences reached (\(self.maxGeofences))")
            return
        }

        let effectiveRadius = min(radius, locationManager.maximumRegionMonitoringDistance)
        let region = CLCircularRegion(
            center: coordinate,
            radius: effectiveRadius,
            identifier: identifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true

        locationManager.startMonitoring(for: region)

        DispatchQueue.main.async {
            self.monitoredRegions.append(region)
        }

        GeofenceLogger.logGeofenceAdd(identifier, coordinate: coordinate, radius: effectiveRadius)
    }

    /// Remove a geofence by identifier
    func removeGeofence(identifier: String) {
        guard let region = monitoredRegions.first(where: { $0.identifier == identifier }) else {
            logger.debug("⚠️ Cannot remove geofence '\(identifier)' - not found")
            return
        }

        locationManager.stopMonitoring(for: region)

        DispatchQueue.main.async {
            self.monitoredRegions.removeAll { $0.identifier == identifier }
        }

        GeofenceLogger.logGeofenceRemove(identifier)
    }

    /// Remove all geofences
    func removeAllGeofences() {
        let count = monitoredRegions.count
        for region in monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }

        DispatchQueue.main.async {
            self.monitoredRegions.removeAll()
        }

        if count > 0 {
            logger.info("Removed all \(count) geofences")
        }
    }

    /// Sync geofences with saved Places
    func syncGeofencesWithPlaces(_ places: [Place]) {
        GeofenceLogger.logGeofenceSync(placesCount: places.count, currentCount: monitoredRegions.count)

        // Remove old geofences
        removeAllGeofences()

        // Clear and rebuild place name lookup
        placeNames.removeAll()

        // Add geofence for each place
        for place in places.prefix(maxGeofences) {
            // Store place name for notifications
            placeNames[place.id] = place.name

            addGeofence(
                identifier: place.id,
                coordinate: place.coordinate,
                radius: place.radius
            )
        }

        logger.info("Geofence sync complete: \(min(places.count, self.maxGeofences)) geofences active")
    }

    /// Get place name for a geofence ID
    func placeName(for geofenceId: String) -> String {
        return placeNames[geofenceId] ?? "Unknown Place"
    }

    /// Check distance from current location to all monitored geofences (for debugging)
    func logDistancesToGeofences() {
        #if DEBUG
        guard let location = currentLocation else {
            print("📏 [DISTANCE] No current location available")
            return
        }

        let currentCL = CLLocation(latitude: location.latitude, longitude: location.longitude)

        print("📏 [DISTANCE] Checking distances to \(monitoredRegions.count) geofences:")
        for region in monitoredRegions {
            let regionCenter = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
            let distance = currentCL.distance(from: regionCenter)
            GeofenceLogger.logDistanceToGeofence(region.identifier, distance: distance, radius: region.radius)
        }
        #endif
    }

    // MARK: - Location Processing

    private func processLocation(_ clLocation: CLLocation) {
        totalLocationsReceived += 1

        // Step 1: Accuracy filtering
        let effectiveThreshold = enableMotionAdaptive ? motionState.accuracyThreshold : accuracyThreshold

        guard clLocation.horizontalAccuracy >= 0,
              clLocation.horizontalAccuracy <= effectiveThreshold else {
            locationsRejected += 1
            rejectedLocationCount += 1

            // If we've rejected too many in a row, accept the best of what we have
            if rejectedLocationCount > 5 {
                acceptLocationWithWarning(clLocation)
            }
            return
        }

        rejectedLocationCount = 0
        acceptLocation(clLocation)
    }

    private func acceptLocation(_ clLocation: CLLocation) {
        locationsAccepted += 1

        // Determine source based on available info
        let source = determineLocationSource(clLocation)

        // Log the accepted location
        GeofenceLogger.logLocationUpdate(
            lat: clLocation.coordinate.latitude,
            lon: clLocation.coordinate.longitude,
            accuracy: clLocation.horizontalAccuracy,
            source: source.rawValue,
            accepted: true
        )

        // Get floor from altimeter if available, otherwise from CLLocation
        let floorLevel: Int?
        #if os(iOS)
        floorLevel = currentFloor?.level ?? clLocation.floor?.level
        #else
        floorLevel = clLocation.floor?.level
        #endif

        // Create precision location with floor data
        var precisionLocation = PrecisionLocation(
            latitude: clLocation.coordinate.latitude,
            longitude: clLocation.coordinate.longitude,
            altitude: clLocation.altitude,
            horizontalAccuracy: clLocation.horizontalAccuracy,
            verticalAccuracy: clLocation.verticalAccuracy >= 0 ? clLocation.verticalAccuracy : nil,
            course: clLocation.course >= 0 ? clLocation.course : nil,
            speed: clLocation.speed >= 0 ? clLocation.speed : nil,
            timestamp: clLocation.timestamp,
            source: source,
            floor: floorLevel
        )

        // Apply Kalman smoothing if enabled
        if enableSmoothing {
            precisionLocation = smoother.smooth(precisionLocation)
        }

        // Update state
        DispatchQueue.main.async {
            self.lastAcceptedLocation = clLocation
            self.currentLocation = precisionLocation
            self.locationError = nil
            self.addToHistory(precisionLocation)
        }
    }

    private func acceptLocationWithWarning(_ clLocation: CLLocation) {
        // Accept a lower-quality location but mark it appropriately
        locationsAccepted += 1
        rejectedLocationCount = 0

        let source = LocationSource.cached  // Mark as lower confidence
        let precisionLocation = PrecisionLocation(from: clLocation, source: source)

        DispatchQueue.main.async {
            self.lastAcceptedLocation = clLocation
            self.currentLocation = precisionLocation
            self.addToHistory(precisionLocation)
        }
    }

    private func determineLocationSource(_ location: CLLocation) -> LocationSource {
        // Heuristics to determine location source
        // Apple doesn't expose this directly, so we infer

        if location.horizontalAccuracy <= 5 {
            return .gnss  // Very accurate = likely GPS with good signal
        } else if location.horizontalAccuracy <= 20 {
            return .fused  // Good accuracy = probably fused
        } else if location.horizontalAccuracy <= 65 {
            return .wifi  // Wi-Fi typically gives ~65m accuracy
        } else {
            return .cellular  // Poor accuracy = likely cell tower
        }
    }

    private func addToHistory(_ location: PrecisionLocation) {
        locationHistory.append(location)
        if locationHistory.count > maxHistoryCount {
            locationHistory.removeFirst()
        }
    }

    // MARK: - Debug & Stats

    var acceptanceRate: Double {
        guard totalLocationsReceived > 0 else { return 0 }
        return Double(locationsAccepted) / Double(totalLocationsReceived) * 100
    }

    func resetStats() {
        totalLocationsReceived = 0
        locationsAccepted = 0
        locationsRejected = 0
        locationHistory.removeAll()
        smoother.reset()
    }
}

// MARK: - CLLocationManagerDelegate

extension PrecisionLocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if manager.authorizationStatus == .authorizedAlways {
                enableBackgroundTracking()
            }
            startTracking()
        case .notDetermined:
            requestPermission()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.locationError = nil
                self.isTracking = false
            }
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Process all locations, not just the last one
        // This helps with accuracy filtering - we might reject recent but accept older
        for location in locations {
            processLocation(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = error
        }

        #if DEBUG
        logger.error("Location error: \(error.localizedDescription)")
        #endif
    }

    // MARK: - Geofence Delegate Methods

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }

        let placeId = circularRegion.identifier
        let name = placeName(for: placeId)

        GeofenceLogger.logGeofenceEntry(placeId)

        // Log distance for verification
        if let location = currentLocation {
            let currentCL = CLLocation(latitude: location.latitude, longitude: location.longitude)
            let regionCenter = CLLocation(latitude: circularRegion.center.latitude, longitude: circularRegion.center.longitude)
            let distance = currentCL.distance(from: regionCenter)
            GeofenceLogger.logDistanceToGeofence(placeId, distance: distance, radius: circularRegion.radius)
        }

        // Send local notification
        Task { @MainActor in
            NotificationService.shared.notifyGeofenceEntry(placeName: name, placeId: placeId)

            // Record for insights
            if let location = currentLocation {
                InsightsService.shared.recordPlaceEntry(
                    placeId: placeId,
                    placeName: name,
                    coordinate: location.coordinate
                )
            }
        }

        // Post notification for the app to handle
        NotificationCenter.default.post(
            name: .didEnterGeofence,
            object: nil,
            userInfo: ["regionId": placeId, "placeName": name]
        )

        // If in background, get one accurate location update
        if isInBackground {
            locationManager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }

        let placeId = circularRegion.identifier
        let name = placeName(for: placeId)

        GeofenceLogger.logGeofenceExit(placeId)

        // Log distance for verification
        if let location = currentLocation {
            let currentCL = CLLocation(latitude: location.latitude, longitude: location.longitude)
            let regionCenter = CLLocation(latitude: circularRegion.center.latitude, longitude: circularRegion.center.longitude)
            let distance = currentCL.distance(from: regionCenter)
            GeofenceLogger.logDistanceToGeofence(placeId, distance: distance, radius: circularRegion.radius)
        }

        // Send local notification
        Task { @MainActor in
            NotificationService.shared.notifyGeofenceExit(placeName: name, placeId: placeId)

            // Record for insights
            if let location = currentLocation {
                InsightsService.shared.recordPlaceExit(
                    placeId: placeId,
                    placeName: name,
                    coordinate: location.coordinate
                )
            }
        }

        // Post notification for the app to handle
        NotificationCenter.default.post(
            name: .didExitGeofence,
            object: nil,
            userInfo: ["regionId": placeId, "placeName": name]
        )

        // When leaving a known place, get accurate location
        if isInBackground {
            locationManager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        GeofenceLogger.logMonitoringStarted(region.identifier)

        // Request initial state for this region
        locationManager.requestState(for: region)
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        GeofenceLogger.logMonitoringFailed(region?.identifier, error: error)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        let stateString: String
        switch state {
        case .inside: stateString = "INSIDE"
        case .outside: stateString = "OUTSIDE"
        case .unknown: stateString = "UNKNOWN"
        }
        logger.info("Region state: '\(region.identifier)' = \(stateString)")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didEnterGeofence = Notification.Name("didEnterGeofence")
    static let didExitGeofence = Notification.Name("didExitGeofence")
}
