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
    case cycling = "cycling"
    case driving = "driving"
    case unknown = "unknown"

    var updateInterval: TimeInterval {
        switch self {
        case .stationary: return 60    // Update every 60s when still (battery save)
        case .walking: return 15       // Update every 15s when walking
        case .running: return 8        // Update every 8s when running
        case .cycling: return 5        // Update every 5s when cycling
        case .driving: return 3        // Update every 3s when driving
        case .unknown: return 15
        }
    }

    var accuracyThreshold: Double {
        switch self {
        case .stationary: return 100   // Accept 100m when stationary (battery save)
        case .walking: return 30       // Need 30m when walking
        case .running: return 30
        case .cycling: return 40
        case .driving: return 50       // Allow 50m when driving (GPS works well)
        case .unknown: return 50
        }
    }

    var displayName: String {
        switch self {
        case .stationary: return "Stationary"
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .driving: return "Driving"
        case .unknown: return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .stationary: return "figure.stand"
        case .walking: return "figure.walk"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .driving: return "car.fill"
        case .unknown: return "questionmark"
        }
    }

    /// Estimated speed range in m/s
    var speedRange: ClosedRange<Double> {
        switch self {
        case .stationary: return 0...0.5
        case .walking: return 0.5...2.5      // 1.8-9 km/h
        case .running: return 2.5...6        // 9-21.6 km/h
        case .cycling: return 3...12         // 10.8-43.2 km/h
        case .driving: return 8...50         // 28.8-180 km/h
        case .unknown: return 0...50
        }
    }
}

// MARK: - Driving Alert

struct DrivingAlert: Identifiable {
    let id = UUID()
    let type: DrivingAlertType
    let speed: Double // m/s
    let speedLimit: Double? // m/s, if known
    let timestamp: Date
    let coordinate: CLLocationCoordinate2D

    var speedKmh: Double { speed * 3.6 }
    var speedLimitKmh: Double? { speedLimit.map { $0 * 3.6 } }
}

enum DrivingAlertType: String {
    case speeding = "speeding"
    case hardBraking = "hard_braking"
    case rapidAcceleration = "rapid_acceleration"
    case phoneUsage = "phone_usage"  // Detected when screen is on while driving
}

// MARK: - Extended Kalman Filter

/// Extended Kalman filter with velocity prediction for location smoothing
class ExtendedKalmanFilter {
    // State: [position, velocity]
    private var position: Double = 0
    private var velocity: Double = 0

    // Covariance matrix (simplified to variances)
    private var positionVariance: Double = 1
    private var velocityVariance: Double = 1

    // Process noise
    private var processNoisePosition: Double
    private var processNoiseVelocity: Double

    // Last update time for dt calculation
    private var lastUpdateTime: Date?

    init(processNoisePosition: Double = 0.00001, processNoiseVelocity: Double = 0.0001) {
        self.processNoisePosition = processNoisePosition
        self.processNoiseVelocity = processNoiseVelocity
    }

    func update(measurement: Double, measurementError: Double, timestamp: Date) -> (position: Double, velocity: Double) {
        // Calculate time delta
        let dt: Double
        if let lastTime = lastUpdateTime {
            dt = timestamp.timeIntervalSince(lastTime)
        } else {
            dt = 1.0
        }
        lastUpdateTime = timestamp

        // Clamp dt to reasonable values
        let clampedDt = min(max(dt, 0.1), 30.0)

        // Prediction step: x_pred = x + v * dt
        let predictedPosition = position + velocity * clampedDt
        let predictedVelocity = velocity

        // Predicted covariance
        let predictedPosVar = positionVariance + velocityVariance * clampedDt * clampedDt + processNoisePosition
        let predictedVelVar = velocityVariance + processNoiseVelocity

        // Kalman gain for position
        let kalmanGain = predictedPosVar / (predictedPosVar + measurementError)

        // Update step
        let innovation = measurement - predictedPosition
        position = predictedPosition + kalmanGain * innovation

        // Update velocity estimate based on innovation
        if clampedDt > 0.1 {
            let velocityInnovation = innovation / clampedDt
            let velocityKalmanGain = 0.3 // Slower adaptation for velocity
            velocity = predictedVelocity + velocityKalmanGain * velocityInnovation
        }

        // Update covariance
        positionVariance = (1 - kalmanGain) * predictedPosVar
        velocityVariance = predictedVelVar * 0.95 // Slight decay

        return (position, velocity)
    }

    func reset(to value: Double, velocity: Double = 0) {
        self.position = value
        self.velocity = velocity
        self.positionVariance = 1
        self.velocityVariance = 1
        self.lastUpdateTime = nil
    }

    var currentEstimate: Double { position }
    var currentVelocity: Double { velocity }
}

// MARK: - Simple Kalman Filter (for backward compatibility)

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

/// Applies Extended Kalman filtering with velocity prediction to smooth location updates
class LocationSmoother {
    private var latFilter: ExtendedKalmanFilter
    private var lonFilter: ExtendedKalmanFilter
    private var altFilter: KalmanFilter
    private var courseFilter: KalmanFilter
    private var isInitialized = false

    // Outlier detection
    private var lastAcceptedLocation: PrecisionLocation?
    private let maxJumpDistance: Double = 500 // meters - reject jumps larger than this

    // Current motion state for adaptive filtering
    private var currentMotionState: MotionState = .unknown

    // Source weighting - different sources have different reliability
    // Lower multiplier = MORE trust (accuracy reported is accurate)
    // Higher multiplier = LESS trust (accuracy is optimistic, inflate it)
    private let sourceAccuracyMultiplier: [LocationSource: Double] = [
        .gnss: 1.0,      // Trust GPS accuracy as-is
        .fused: 0.85,    // Apple's fused is often BETTER than reported (uses WiFi DB, beacons, ML)
        .wifi: 1.5,      // WiFi can have optimistic accuracy
        .cellular: 2.0,  // Cell is usually less accurate than reported
        .cached: 3.0,    // Cached locations are least reliable
        .unknown: 1.5
    ]

    // Adaptive process noise based on motion state
    // Lower noise = smoother output, trusts prediction more
    // Higher noise = more responsive, trusts measurements more
    private func processNoiseForMotion(_ state: MotionState) -> (position: Double, velocity: Double) {
        switch state {
        case .stationary:
            // Very low noise - person isn't moving, trust our position estimate
            return (0.000001, 0.00001)
        case .walking:
            // Low noise - walking is predictable
            return (0.00001, 0.0001)
        case .running:
            // Medium noise - running can have more variation
            return (0.00005, 0.0005)
        case .cycling:
            // Medium noise - cycling is fairly predictable
            return (0.00003, 0.0003)
        case .driving:
            // Higher noise - driving has more speed variation, need responsiveness
            return (0.0001, 0.001)
        case .unknown:
            // Default moderate noise
            return (0.00003, 0.0003)
        }
    }

    init() {
        latFilter = ExtendedKalmanFilter(processNoisePosition: 0.00001, processNoiseVelocity: 0.0001)
        lonFilter = ExtendedKalmanFilter(processNoisePosition: 0.00001, processNoiseVelocity: 0.0001)
        altFilter = KalmanFilter(processNoise: 0.5)
        courseFilter = KalmanFilter(processNoise: 5.0)
    }

    /// Update the motion state for adaptive filtering
    func updateMotionState(_ state: MotionState) {
        guard state != currentMotionState else { return }
        currentMotionState = state

        // Adjust Kalman filter process noise based on motion
        let noise = processNoiseForMotion(state)
        latFilter = ExtendedKalmanFilter(processNoisePosition: noise.position, processNoiseVelocity: noise.velocity)
        lonFilter = ExtendedKalmanFilter(processNoisePosition: noise.position, processNoiseVelocity: noise.velocity)

        // Reset filters on major state change to avoid lag
        if let lastLoc = lastAcceptedLocation {
            latFilter.reset(to: lastLoc.latitude)
            lonFilter.reset(to: lastLoc.longitude)
        }
    }

    func smooth(_ location: PrecisionLocation) -> PrecisionLocation {
        // Outlier detection - reject impossible jumps
        if let lastLocation = lastAcceptedLocation {
            let distance = location.distance(to: lastLocation)
            let timeDelta = location.timestamp.timeIntervalSince(lastLocation.timestamp)

            // Calculate max possible distance based on time and reasonable max speed (200 km/h)
            let maxPossibleDistance = max(timeDelta * 55.5, maxJumpDistance) // 55.5 m/s = 200 km/h

            if distance > maxPossibleDistance && timeDelta < 60 {
                // Likely an erroneous jump - return last known good location with updated timestamp
                #if DEBUG
                print("⚠️ Rejected location jump: \(Int(distance))m in \(Int(timeDelta))s")
                #endif
                return lastLocation
            }
        }

        if !isInitialized {
            latFilter.reset(to: location.latitude)
            lonFilter.reset(to: location.longitude)
            if let alt = location.altitude {
                altFilter.reset(to: alt)
            }
            if let course = location.course {
                courseFilter.reset(to: course)
            }
            isInitialized = true
            lastAcceptedLocation = location
            return location
        }

        // Apply source-based accuracy adjustment
        let sourceMultiplier = sourceAccuracyMultiplier[location.source] ?? 1.5
        let adjustedAccuracy = location.horizontalAccuracy * sourceMultiplier

        // Convert accuracy to degrees for lat/lon filtering
        let accuracyInDegrees = adjustedAccuracy / 111000  // ~111km per degree

        // Apply extended Kalman filter with velocity prediction
        let (smoothedLat, _) = latFilter.update(
            measurement: location.latitude,
            measurementError: accuracyInDegrees,
            timestamp: location.timestamp
        )
        let (smoothedLon, _) = lonFilter.update(
            measurement: location.longitude,
            measurementError: accuracyInDegrees / cos(location.latitude * .pi / 180), // Adjust for longitude scale
            timestamp: location.timestamp
        )

        // Smooth altitude if available
        var smoothedAltitude = location.altitude
        if let alt = location.altitude {
            smoothedAltitude = altFilter.update(measurement: alt, measurementError: location.verticalAccuracy ?? 10)
        }

        // Smooth course for heading stability
        var smoothedCourse = location.course
        if let course = location.course, course >= 0 {
            // Handle wraparound at 0/360
            var currentCourse = courseFilter.update(measurement: course, measurementError: 10)
            currentCourse = currentCourse.truncatingRemainder(dividingBy: 360)
            if currentCourse < 0 { currentCourse += 360 }
            smoothedCourse = currentCourse
        }

        // Calculate improved accuracy estimate based on filter convergence and motion state
        // Stationary gets bigger improvement (more averaging), moving gets less
        let motionAccuracyFactor: Double
        switch currentMotionState {
        case .stationary:
            motionAccuracyFactor = 0.6  // 40% improvement when stationary (lots of averaging)
        case .walking:
            motionAccuracyFactor = 0.75 // 25% improvement
        case .running, .cycling:
            motionAccuracyFactor = 0.85 // 15% improvement
        case .driving:
            motionAccuracyFactor = 0.9  // 10% improvement (need responsiveness)
        case .unknown:
            motionAccuracyFactor = 0.8  // 20% improvement default
        }
        let improvedAccuracy = min(location.horizontalAccuracy, adjustedAccuracy * motionAccuracyFactor)

        let smoothedLocation = PrecisionLocation(
            id: location.id,
            latitude: smoothedLat,
            longitude: smoothedLon,
            altitude: smoothedAltitude,
            horizontalAccuracy: improvedAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            course: smoothedCourse,
            speed: location.speed,
            timestamp: location.timestamp,
            source: location.source,
            floor: location.floor
        )

        lastAcceptedLocation = smoothedLocation
        return smoothedLocation
    }

    /// Get predicted position based on current velocity
    func predictPosition(afterSeconds seconds: Double) -> CLLocationCoordinate2D? {
        guard isInitialized else { return nil }

        let predictedLat = latFilter.currentEstimate + latFilter.currentVelocity * seconds
        let predictedLon = lonFilter.currentEstimate + lonFilter.currentVelocity * seconds

        return CLLocationCoordinate2D(latitude: predictedLat, longitude: predictedLon)
    }

    func reset() {
        isInitialized = false
        lastAcceptedLocation = nil
    }
}

// MARK: - Sensor Fusion

/// Multi-source sensor fusion for optimal location accuracy
class SensorFusion {
    // Weighted combination of multiple location sources
    private var sourceHistory: [LocationSource: [CLLocation]] = [:]
    private let maxHistoryPerSource = 3

    /// Fuse multiple location readings to produce the best estimate
    func fuseLocations(_ locations: [CLLocation], sources: [LocationSource]) -> (CLLocation, LocationSource)? {
        guard !locations.isEmpty else { return nil }

        // If only one location, return it
        if locations.count == 1 {
            return (locations[0], sources.first ?? .unknown)
        }

        // Weight each location by its accuracy (inverse variance weighting)
        var totalWeight: Double = 0
        var weightedLat: Double = 0
        var weightedLon: Double = 0
        var weightedAlt: Double = 0
        var altCount = 0
        var bestAccuracy: Double = .infinity

        for (index, location) in locations.enumerated() {
            guard location.horizontalAccuracy > 0 else { continue }

            // Apply source-specific trust factor
            let source = index < sources.count ? sources[index] : .unknown
            let trustFactor = sourceTrustFactor(source)

            // Weight is inverse of variance (accuracy^2), adjusted by trust factor
            let weight = trustFactor / (location.horizontalAccuracy * location.horizontalAccuracy)

            weightedLat += location.coordinate.latitude * weight
            weightedLon += location.coordinate.longitude * weight
            totalWeight += weight

            if location.altitude != 0 {
                weightedAlt += location.altitude * weight
                altCount += 1
            }

            if location.horizontalAccuracy < bestAccuracy {
                bestAccuracy = location.horizontalAccuracy
            }
        }

        guard totalWeight > 0 else { return nil }

        // Calculate weighted average
        let fusedLat = weightedLat / totalWeight
        let fusedLon = weightedLon / totalWeight
        let fusedAlt = altCount > 0 ? weightedAlt / totalWeight : 0

        // Fused accuracy is better than best individual (by combining information)
        let fusedAccuracy = bestAccuracy * 0.8

        let fusedLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: fusedLat, longitude: fusedLon),
            altitude: fusedAlt,
            horizontalAccuracy: fusedAccuracy,
            verticalAccuracy: -1,
            timestamp: locations.last?.timestamp ?? Date()
        )

        return (fusedLocation, .fused)
    }

    /// Calculate consistency score between multiple readings
    func consistencyScore(locations: [CLLocation]) -> Double {
        guard locations.count >= 2 else { return 1.0 }

        var totalDistance: Double = 0
        let referenceLocation = locations[0]

        for location in locations.dropFirst() {
            totalDistance += referenceLocation.distance(from: location)
        }

        let avgDistance = totalDistance / Double(locations.count - 1)

        // Score from 0 to 1 (1 = all readings are identical)
        // 0 when avgDistance >= 100m
        return max(0, 1 - (avgDistance / 100))
    }

    /// Detect potential GPS spoofing or anomalies
    func detectAnomaly(newLocation: CLLocation, history: [CLLocation]) -> Bool {
        guard let lastLocation = history.last else { return false }

        let distance = newLocation.distance(from: lastLocation)
        let timeDelta = newLocation.timestamp.timeIntervalSince(lastLocation.timestamp)

        guard timeDelta > 0 else { return true } // Same timestamp = suspicious

        let speed = distance / timeDelta // m/s

        // Flag if speed exceeds ~400 km/h (111 m/s) - faster than commercial aircraft
        if speed > 111 {
            return true
        }

        // Flag if accuracy suddenly becomes impossibly good
        if newLocation.horizontalAccuracy < 1 && lastLocation.horizontalAccuracy > 20 {
            return true
        }

        return false
    }

    private func sourceTrustFactor(_ source: LocationSource) -> Double {
        // Higher = more trust (used as weight in fusion)
        switch source {
        case .gnss: return 1.0      // Raw GPS is baseline
        case .fused: return 1.15    // Apple's fused often better - uses WiFi DB, beacons, crowd-sourced data
        case .wifi: return 0.7      // WiFi alone is decent
        case .cellular: return 0.4  // Cell towers are rough
        case .cached: return 0.2    // Stale data
        case .unknown: return 0.5
        }
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

    // Driving detection and alerts
    @Published var isDriving: Bool = false
    @Published var currentSpeed: Double = 0 // m/s
    @Published var drivingAlerts: [DrivingAlert] = []
    @Published var tripStartTime: Date?
    @Published var tripDistance: Double = 0 // meters

    // Speed alert configuration
    @AppStorage("speedAlertThreshold") private var speedAlertThreshold: Double = 33.33 // 120 km/h default
    @AppStorage("enableSpeedAlerts") private var enableSpeedAlerts: Bool = true
    @AppStorage("enableDrivingDetection") private var enableDrivingDetection: Bool = true

    // Location history for patterns and debugging
    @Published var locationHistory: [PrecisionLocation] = []
    private let maxHistoryCount = 100

    // Driving detection state
    private var speedHistory: [Double] = []
    private let speedHistorySize = 5
    private var lastDrivingAlertTime: Date?
    private let minAlertInterval: TimeInterval = 60 // Don't spam alerts

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
    private let sensorFusion = SensorFusion()

    private var lastAcceptedLocation: CLLocation?
    private var rejectedLocationCount = 0
    private var updateTimer: Timer?

    // Recent locations buffer for multi-source fusion
    private var recentLocations: [CLLocation] = []
    private let recentLocationBufferSize = 5
    private let recentLocationMaxAge: TimeInterval = 10 // seconds

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
        } else if activity.cycling {
            newState = .cycling
        } else if activity.automotive {
            newState = .driving
        } else {
            newState = .unknown
        }

        if newState != motionState {
            DispatchQueue.main.async {
                self.motionState = newState
                self.smoother.updateMotionState(newState)  // Adaptive Kalman filtering
                self.adaptToMotionState()
            }
        }
    }
    #endif

    private func adaptToMotionState() {
        guard enableMotionAdaptive else { return }

        // Adjust accuracy and power based on motion state
        switch motionState {
        case .stationary:
            // Maximum battery saving when not moving
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 50 // Only update if moved 50m
            locationManager.activityType = .other
        case .walking:
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.distanceFilter = 10
            locationManager.activityType = .fitness
        case .running:
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = 5
            locationManager.activityType = .fitness
        case .cycling:
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = 10
            locationManager.activityType = .fitness
        case .driving:
            // Best accuracy for navigation
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locationManager.distanceFilter = kCLDistanceFilterNone
            locationManager.activityType = .automotiveNavigation
            handleDrivingStarted()
        case .unknown:
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = 20
            locationManager.activityType = .other
        }

        // If we stopped driving, record trip end
        if motionState != .driving && isDriving {
            handleDrivingEnded()
        }
    }

    // MARK: - Driving Detection & Speed Alerts

    private func handleDrivingStarted() {
        guard enableDrivingDetection else { return }

        if !isDriving {
            DispatchQueue.main.async {
                self.isDriving = true
                self.tripStartTime = Date()
                self.tripDistance = 0
            }

            #if DEBUG
            print("🚗 [DRIVING] Trip started")
            #endif
        }
    }

    private func handleDrivingEnded() {
        guard isDriving else { return }

        let duration = tripStartTime.map { Date().timeIntervalSince($0) } ?? 0

        DispatchQueue.main.async {
            self.isDriving = false

            #if DEBUG
            print("🚗 [DRIVING] Trip ended - Distance: \(Int(self.tripDistance))m, Duration: \(Int(duration))s")
            #endif
        }
    }

    private func updateSpeedTracking(_ speed: Double, coordinate: CLLocationCoordinate2D) {
        guard enableDrivingDetection else { return }

        // Update current speed
        DispatchQueue.main.async {
            self.currentSpeed = max(0, speed)
        }

        // Maintain speed history for smoothing and analysis
        speedHistory.append(speed)
        if speedHistory.count > speedHistorySize {
            speedHistory.removeFirst()
        }

        // Calculate average speed
        let avgSpeed = speedHistory.reduce(0, +) / Double(speedHistory.count)

        // Detect driving from speed if motion detection missed it
        if avgSpeed > 10 && !isDriving && enableDrivingDetection { // > 36 km/h
            DispatchQueue.main.async {
                self.motionState = .driving
            }
            handleDrivingStarted()
        }

        // Update trip distance
        if isDriving, let lastLocation = lastAcceptedLocation {
            let newLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let delta = newLocation.distance(from: lastLocation)
            if delta < 1000 { // Sanity check - ignore jumps > 1km
                DispatchQueue.main.async {
                    self.tripDistance += delta
                }
            }
        }

        // Check for speed alerts
        checkSpeedAlerts(speed: speed, coordinate: coordinate)

        // Check for harsh driving events
        detectHarshDrivingEvents(currentSpeed: speed)
    }

    private func checkSpeedAlerts(speed: Double, coordinate: CLLocationCoordinate2D) {
        guard enableSpeedAlerts, isDriving else { return }
        guard speed > speedAlertThreshold else { return }

        // Rate limit alerts
        if let lastAlert = lastDrivingAlertTime,
           Date().timeIntervalSince(lastAlert) < minAlertInterval {
            return
        }

        let alert = DrivingAlert(
            type: .speeding,
            speed: speed,
            speedLimit: nil, // TODO: Integrate speed limit data
            timestamp: Date(),
            coordinate: coordinate
        )

        DispatchQueue.main.async {
            self.drivingAlerts.append(alert)
            self.lastDrivingAlertTime = Date()
        }

        // Send notification
        Task { @MainActor in
            NotificationService.shared.notifySpeedAlert(
                speed: speed * 3.6, // Convert to km/h
                limit: self.speedAlertThreshold * 3.6
            )
        }

        #if DEBUG
        print("⚠️ [SPEED] Alert: \(Int(speed * 3.6)) km/h exceeds threshold")
        #endif
    }

    private func detectHarshDrivingEvents(currentSpeed: Double) {
        guard speedHistory.count >= 2, isDriving else { return }

        let previousSpeed = speedHistory[speedHistory.count - 2]
        let speedDelta = currentSpeed - previousSpeed

        // Hard braking: deceleration > 3 m/s² (assuming 1s intervals)
        if speedDelta < -3 && currentSpeed > 5 {
            let alert = DrivingAlert(
                type: .hardBraking,
                speed: currentSpeed,
                speedLimit: nil,
                timestamp: Date(),
                coordinate: currentLocation?.coordinate ?? CLLocationCoordinate2D()
            )

            DispatchQueue.main.async {
                self.drivingAlerts.append(alert)
            }

            #if DEBUG
            print("⚠️ [DRIVING] Hard braking detected")
            #endif
        }

        // Rapid acceleration: > 4 m/s²
        if speedDelta > 4 && previousSpeed > 2 {
            let alert = DrivingAlert(
                type: .rapidAcceleration,
                speed: currentSpeed,
                speedLimit: nil,
                timestamp: Date(),
                coordinate: currentLocation?.coordinate ?? CLLocationCoordinate2D()
            )

            DispatchQueue.main.async {
                self.drivingAlerts.append(alert)
            }

            #if DEBUG
            print("⚠️ [DRIVING] Rapid acceleration detected")
            #endif
        }
    }

    /// Clear driving alerts (e.g., after viewing)
    func clearDrivingAlerts() {
        drivingAlerts.removeAll()
    }

    /// Set custom speed alert threshold (in km/h)
    func setSpeedAlertThreshold(kmh: Double) {
        speedAlertThreshold = kmh / 3.6 // Store as m/s
    }

    /// Get current speed in km/h
    var currentSpeedKmh: Double {
        currentSpeed * 3.6
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

        // Step 0: Anomaly detection - reject obviously bad locations
        if sensorFusion.detectAnomaly(newLocation: clLocation, history: recentLocations) {
            locationsRejected += 1
            #if DEBUG
            print("⚠️ Anomaly detected, rejecting location")
            #endif
            return
        }

        // Step 1: Add to recent buffer for multi-source fusion
        addToRecentBuffer(clLocation)

        // Step 2: Accuracy filtering
        let effectiveThreshold = enableMotionAdaptive ? motionState.accuracyThreshold : accuracyThreshold

        guard clLocation.horizontalAccuracy >= 0,
              clLocation.horizontalAccuracy <= effectiveThreshold else {
            locationsRejected += 1
            rejectedLocationCount += 1

            // If we've rejected too many in a row, try to use fused location from buffer
            if rejectedLocationCount > 5 {
                if let fusedResult = attemptFusedLocation() {
                    acceptLocation(fusedResult.0, source: fusedResult.1)
                } else {
                    acceptLocationWithWarning(clLocation)
                }
            }
            return
        }

        rejectedLocationCount = 0

        // Step 3: Try multi-source fusion for better accuracy
        if let fusedResult = attemptFusedLocation() {
            // Use fused if it's better than current
            if fusedResult.0.horizontalAccuracy < clLocation.horizontalAccuracy {
                acceptLocation(fusedResult.0, source: fusedResult.1)
                return
            }
        }

        acceptLocation(clLocation)
    }

    private func addToRecentBuffer(_ location: CLLocation) {
        // Remove old entries
        let cutoff = Date().addingTimeInterval(-recentLocationMaxAge)
        recentLocations.removeAll { $0.timestamp < cutoff }

        // Add new location
        recentLocations.append(location)

        // Trim to max size
        if recentLocations.count > recentLocationBufferSize {
            recentLocations.removeFirst(recentLocations.count - recentLocationBufferSize)
        }
    }

    private func attemptFusedLocation() -> (CLLocation, LocationSource)? {
        guard recentLocations.count >= 2 else { return nil }

        // Determine sources for each location (heuristic based on accuracy)
        let sources = recentLocations.map { determineLocationSource($0) }

        return sensorFusion.fuseLocations(recentLocations, sources: sources)
    }

    private func acceptLocation(_ clLocation: CLLocation, source: LocationSource? = nil) {
        locationsAccepted += 1

        // Determine source based on available info (or use provided)
        let locationSource = source ?? determineLocationSource(clLocation)

        // Log the accepted location
        GeofenceLogger.logLocationUpdate(
            lat: clLocation.coordinate.latitude,
            lon: clLocation.coordinate.longitude,
            accuracy: clLocation.horizontalAccuracy,
            source: locationSource.rawValue,
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
            source: locationSource,
            floor: floorLevel
        )

        // Apply Kalman smoothing if enabled
        if enableSmoothing {
            precisionLocation = smoother.smooth(precisionLocation)
        }

        // Track speed for driving detection
        if clLocation.speed >= 0 {
            updateSpeedTracking(clLocation.speed, coordinate: clLocation.coordinate)
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
        // Apple doesn't expose this directly, so we infer from accuracy patterns

        let accuracy = location.horizontalAccuracy

        // Apple's fused location typically has these characteristics:
        // - Accuracy in 5-30m range (better than raw GPS indoors, similar outdoors)
        // - Consistent readings without GPS jitter
        // - Available even when GPS alone would struggle

        if accuracy <= 5 {
            // Very high accuracy - could be fused with strong signals or pure GPS
            // Treat as fused since Apple likely enhanced it
            return .fused
        } else if accuracy <= 15 {
            // Excellent accuracy - definitely Apple's fused location working well
            // This is the sweet spot where Apple's fusion shines
            return .fused
        } else if accuracy <= 35 {
            // Good accuracy - likely fused with some uncertainty
            return .fused
        } else if accuracy <= 65 {
            // Moderate accuracy - WiFi-assisted positioning
            return .wifi
        } else if accuracy <= 500 {
            // Poor accuracy - cell tower triangulation
            return .cellular
        } else {
            // Very poor - likely cached or degraded
            return .cached
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

// MARK: - Visit Monitoring Delegate

extension PrecisionLocationManager {

    /// Start visit monitoring for battery-efficient place detection
    func startVisitMonitoring() {
        locationManager.startMonitoringVisits()
        logger.info("Started visit monitoring")
    }

    /// Stop visit monitoring
    func stopVisitMonitoring() {
        locationManager.stopMonitoringVisits()
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let isArrival = visit.departureDate == Date.distantFuture

        logger.info("Visit \(isArrival ? "arrival" : "departure") at (\(visit.coordinate.latitude), \(visit.coordinate.longitude))")

        #if DEBUG
        let emoji = isArrival ? "📍" : "🚶"
        print("\(emoji) [VISIT] \(isArrival ? "Arrived" : "Departed") at (\(visit.coordinate.latitude), \(visit.coordinate.longitude))")
        if !isArrival {
            let duration = visit.departureDate.timeIntervalSince(visit.arrivalDate)
            print("   Duration: \(Int(duration / 60)) minutes")
        }
        #endif

        // Post notification for the app to handle
        NotificationCenter.default.post(
            name: .didReceiveVisit,
            object: nil,
            userInfo: [
                "visit": visit,
                "isArrival": isArrival,
                "coordinate": visit.coordinate
            ]
        )

        // Get a precise location after a visit event
        if isInBackground {
            locationManager.requestLocation()
        }

        // Record for insights
        Task { @MainActor in
            if isArrival {
                InsightsService.shared.recordPlaceEntry(
                    placeId: "visit_\(UUID().uuidString)",
                    placeName: "Visit Location",
                    coordinate: visit.coordinate
                )
            }
        }
    }
}

// MARK: - Battery-Aware Configuration

extension PrecisionLocationManager {

    /// Configure for low power mode
    func configureLowPowerMode() {
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = 500
        locationManager.pausesLocationUpdatesAutomatically = true

        // Stop continuous updates, rely on visits and significant changes
        locationManager.stopUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        startVisitMonitoring()

        logger.info("Configured for low power mode")
    }

    /// Configure for balanced mode (default)
    func configureBalancedMode() {
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100
        locationManager.pausesLocationUpdatesAutomatically = true

        // Use motion-adaptive tracking
        adaptToMotionState()
        startVisitMonitoring()

        logger.info("Configured for balanced mode")
    }

    /// Configure for high accuracy mode
    func configureHighAccuracyMode() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        locationManager.pausesLocationUpdatesAutomatically = false

        locationManager.startUpdatingLocation()
        startVisitMonitoring()

        logger.info("Configured for high accuracy mode")
    }

    /// Respond to system low power mode changes
    func handleLowPowerModeChange(_ isEnabled: Bool) {
        if isEnabled {
            configureLowPowerMode()
        } else {
            configureBalancedMode()
        }
    }
}

// MARK: - Deferred Location Updates

// Note: Deferred location updates were deprecated in iOS 13.0 and removed.
// Battery-efficient location is now handled automatically by iOS via:
// - desiredAccuracy settings
// - activityType configuration
// - allowsBackgroundLocationUpdates
// - pausesLocationUpdatesAutomatically

// MARK: - Notification Names

extension Notification.Name {
    static let didEnterGeofence = Notification.Name("didEnterGeofence")
    static let didExitGeofence = Notification.Name("didExitGeofence")
    static let didReceiveVisit = Notification.Name("didReceiveVisit")
}
