import Foundation
import CoreLocation
import MapKit
import os.log

private let logger = Logger(subsystem: "com.life380.app", category: "ETA")

/// Traffic condition for driving ETAs
enum TrafficCondition: String {
    case light = "light"
    case moderate = "moderate"
    case heavy = "heavy"
    case unknown = "unknown"

    var icon: String {
        switch self {
        case .light: return "car.fill"
        case .moderate: return "car.2.fill"
        case .heavy: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: String {
        switch self {
        case .light: return "green"
        case .moderate: return "yellow"
        case .heavy: return "red"
        case .unknown: return "gray"
        }
    }

    var description: String {
        switch self {
        case .light: return "Light traffic"
        case .moderate: return "Moderate traffic"
        case .heavy: return "Heavy traffic"
        case .unknown: return "Traffic unknown"
        }
    }
}

/// Represents an estimated time of arrival
struct ETAResult: Identifiable {
    let id = UUID()
    let place: Place
    let eta: TimeInterval          // seconds until arrival
    let distance: Double           // meters
    let calculationMethod: ETAMethod
    let confidence: ETAConfidence
    let timestamp: Date
    var travelMode: TravelMode?
    var trafficCondition: TrafficCondition?

    var etaDate: Date {
        Date().addingTimeInterval(eta)
    }

    var etaText: String {
        if eta < 60 {
            return "< 1 min"
        } else if eta < 3600 {
            let minutes = Int(eta / 60)
            return "\(minutes) min"
        } else {
            let hours = Int(eta / 3600)
            let minutes = Int((eta.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }

    var distanceText: String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }

    /// Whether the person is "almost there" (within 5 minutes)
    var isAlmostThere: Bool {
        eta <= 300 && eta > 0
    }

    /// Whether the person has essentially arrived (within 1 minute)
    var hasArrived: Bool {
        eta <= 60
    }

    /// Detailed ETA text with traffic info
    var detailedEtaText: String {
        var text = etaText
        if let traffic = trafficCondition, traffic != .unknown {
            text += " (\(traffic.description.lowercased()))"
        }
        return text
    }
}

enum ETAMethod: String {
    case speedBased = "speed"      // Simple distance/speed calculation
    case mapKit = "mapkit"         // MapKit directions API
    case cached = "cached"         // Cached route from previous calculation
    case historical = "historical" // Based on historical patterns (future)
    case hybrid = "hybrid"         // Combination of methods
}

enum ETAConfidence: String {
    case high = "high"       // MapKit or consistent speed
    case medium = "medium"   // Speed-based with good data
    case low = "low"         // Estimated or stale data

    var color: String {
        switch self {
        case .high: return "green"
        case .medium: return "blue"
        case .low: return "orange"
        }
    }
}

enum TravelMode: String, CaseIterable {
    case walking = "walking"
    case cycling = "cycling"
    case driving = "driving"
    case transit = "transit"

    var icon: String {
        switch self {
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .driving: return "car.fill"
        case .transit: return "tram.fill"
        }
    }

    var averageSpeed: Double { // m/s
        switch self {
        case .walking: return 1.4    // ~5 km/h
        case .cycling: return 5.5    // ~20 km/h
        case .driving: return 11.1   // ~40 km/h (urban average)
        case .transit: return 8.3    // ~30 km/h
        }
    }

    var mapKitTransportType: MKDirectionsTransportType {
        switch self {
        case .walking: return .walking
        case .cycling: return .walking // MapKit doesn't have cycling
        case .driving: return .automobile
        case .transit: return .transit
        }
    }

    /// Detect travel mode from speed
    static func detect(fromSpeed speed: Double) -> TravelMode {
        switch speed {
        case ..<2.5: return .walking
        case 2.5..<8: return .cycling
        case 8..<50: return .driving
        default: return .driving
        }
    }
}

/// Service for calculating estimated arrival times
@MainActor
class ETAService: ObservableObject {
    static let shared = ETAService()

    // Published state
    @Published var activeETAs: [String: [ETAResult]] = [:]  // userId -> ETAs to places
    @Published var approachingAlerts: [ETAResult] = []      // Members almost there

    // Configuration
    private let drivingSpeedThreshold: Double = 10.0  // m/s (~36 km/h)
    private let almostThereThreshold: TimeInterval = 300  // 5 minutes
    private let etaRefreshInterval: TimeInterval = 30     // Recalculate every 30s

    // Cache for MapKit routes
    private var routeCache: [String: CachedRoute] = [:]
    private let routeCacheExpiry: TimeInterval = 300  // 5 minutes

    // Tracking for "almost there" notifications
    private var notifiedApproaching: Set<String> = []  // placeId combinations already notified

    private init() {}

    // MARK: - Main ETA Calculation

    /// Calculate ETA from a user's location to a place using hybrid approach
    func calculateETA(
        from location: PrecisionLocation,
        to place: Place,
        currentSpeed: Double? = nil,
        preferredMode: TravelMode? = nil
    ) async -> ETAResult {
        let fromCoord = location.coordinate
        let toCoord = place.coordinate
        let distance = self.distance(from: fromCoord, to: toCoord)

        // Determine speed and travel mode
        let speed = currentSpeed ?? location.speed ?? 0
        let detectedMode = TravelMode.detect(fromSpeed: speed)
        let travelMode = preferredMode ?? detectedMode

        // For driving, try MapKit with traffic
        if travelMode == .driving && speed > drivingSpeedThreshold {
            if let mapKitETA = await calculateMapKitETAWithTraffic(
                from: fromCoord,
                to: toCoord,
                placeId: place.id,
                transportType: .automobile
            ) {
                return ETAResult(
                    place: place,
                    eta: mapKitETA.eta,
                    distance: distance,
                    calculationMethod: .mapKit,
                    confidence: .high,
                    timestamp: Date(),
                    travelMode: travelMode,
                    trafficCondition: mapKitETA.trafficCondition
                )
            }
        }

        // For walking/cycling, use MapKit walking directions
        if travelMode == .walking || travelMode == .cycling {
            if let mapKitETA = await calculateMapKitETA(
                from: fromCoord,
                to: toCoord,
                placeId: place.id,
                transportType: .walking
            ) {
                // Adjust for cycling (faster than walking)
                let adjustedETA = travelMode == .cycling ? mapKitETA * 0.4 : mapKitETA

                return ETAResult(
                    place: place,
                    eta: adjustedETA,
                    distance: distance,
                    calculationMethod: .mapKit,
                    confidence: .high,
                    timestamp: Date(),
                    travelMode: travelMode
                )
            }
        }

        // Fall back to speed-based calculation
        let speedBasedETA = calculateSpeedBasedETA(
            distance: distance,
            speed: speed > 0.5 ? speed : travelMode.averageSpeed
        )
        let confidence: ETAConfidence = speed > 1 ? .medium : .low

        return ETAResult(
            place: place,
            eta: speedBasedETA,
            distance: distance,
            calculationMethod: .speedBased,
            confidence: confidence,
            timestamp: Date(),
            travelMode: travelMode
        )
    }

    // MARK: - Traffic-Aware MapKit ETA

    private func calculateMapKitETAWithTraffic(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        placeId: String,
        transportType: MKDirectionsTransportType
    ) async -> (eta: TimeInterval, trafficCondition: TrafficCondition)? {
        let cacheKey = "\(placeId)_\(Int(from.latitude * 1000))_\(Int(from.longitude * 1000))_traffic"

        // Check cache first
        if let cached = routeCache[cacheKey], !cached.isExpired {
            return (cached.eta, cached.trafficCondition ?? .unknown)
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = transportType
        request.requestsAlternateRoutes = false
        request.departureDate = Date() // Current time for traffic

        let directions = MKDirections(request: request)

        do {
            let response = try await directions.calculateETA()
            let eta = response.expectedTravelTime

            // Determine traffic condition by comparing expected vs base travel time
            let baseTime = response.distance / 13.9 // ~50 km/h base speed
            let trafficRatio = eta / baseTime
            let trafficCondition: TrafficCondition
            if trafficRatio < 1.2 {
                trafficCondition = .light
            } else if trafficRatio < 1.5 {
                trafficCondition = .moderate
            } else {
                trafficCondition = .heavy
            }

            // Cache the result
            routeCache[cacheKey] = CachedRoute(
                eta: eta,
                distance: response.distance,
                timestamp: Date(),
                trafficCondition: trafficCondition
            )

            logger.info("Traffic-aware ETA to \(placeId): \(Int(eta))s, traffic: \(trafficCondition.rawValue)")
            return (eta, trafficCondition)
        } catch {
            logger.error("Traffic ETA failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Calculate ETAs from a user to all saved places
    func calculateETAsToAllPlaces(
        from location: PrecisionLocation,
        places: [Place]
    ) async -> [ETAResult] {
        var results: [ETAResult] = []

        for place in places {
            let eta = await calculateETA(from: location, to: place, currentSpeed: location.speed)
            results.append(eta)
        }

        // Sort by ETA (closest first)
        return results.sorted { $0.eta < $1.eta }
    }

    /// Check which places a member is approaching (within threshold)
    func checkApproachingPlaces(
        member: UserProfile,
        places: [Place],
        location: PrecisionLocation
    ) async -> [ETAResult] {
        let etas = await calculateETAsToAllPlaces(from: location, places: places)
        return etas.filter { $0.isAlmostThere && !$0.hasArrived }
    }

    // MARK: - Speed-Based Calculation

    private func calculateSpeedBasedETA(distance: Double, speed: Double) -> TimeInterval {
        guard speed > 0.5 else {
            // Stationary or very slow - estimate based on average walking speed
            let walkingSpeed = 1.4  // m/s (~5 km/h)
            return distance / walkingSpeed
        }

        return distance / speed
    }

    // MARK: - MapKit Directions

    private func calculateMapKitETA(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        placeId: String,
        transportType: MKDirectionsTransportType = .automobile
    ) async -> TimeInterval? {
        let cacheKey = "\(placeId)_\(Int(from.latitude * 1000))_\(Int(from.longitude * 1000))_\(transportType.rawValue)"

        // Check cache first
        if let cached = routeCache[cacheKey], !cached.isExpired {
            logger.debug("Using cached route for \(placeId)")
            return cached.eta
        }

        // Request directions from MapKit
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)

        do {
            let response = try await directions.calculateETA()
            let eta = response.expectedTravelTime

            // Cache the result
            routeCache[cacheKey] = CachedRoute(
                eta: eta,
                distance: response.distance,
                timestamp: Date()
            )

            logger.info("MapKit ETA to \(placeId): \(Int(eta))s")
            return eta
        } catch {
            logger.error("MapKit ETA failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - "Almost There" Notifications

    /// Process ETAs and send "almost there" notifications if needed
    func processApproachingNotifications(
        memberName: String,
        memberId: String,
        etas: [ETAResult]
    ) {
        for eta in etas where eta.isAlmostThere {
            let notificationKey = "\(memberId)_\(eta.place.id)"

            // Only notify once per approach
            guard !notifiedApproaching.contains(notificationKey) else { continue }

            // Check if notifications are enabled for this place
            guard eta.place.notificationsEnabled else { continue }

            // Send notification
            NotificationService.shared.notifyApproaching(
                memberName: memberName,
                placeName: eta.place.name,
                eta: eta.etaText
            )

            notifiedApproaching.insert(notificationKey)
            logger.info("Sent approaching notification: \(memberName) -> \(eta.place.name)")
        }
    }

    /// Reset notification tracking when member arrives at a place
    func memberArrivedAt(memberId: String, placeId: String) {
        let key = "\(memberId)_\(placeId)"
        notifiedApproaching.remove(key)
    }

    /// Reset all notification tracking (e.g., on app launch)
    func resetNotificationTracking() {
        notifiedApproaching.removeAll()
    }

    // MARK: - Helpers

    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    /// Clear expired route cache entries
    func clearExpiredCache() {
        let now = Date()
        routeCache = routeCache.filter { !$0.value.isExpired(at: now) }
    }
}

// MARK: - Cache Structure

private struct CachedRoute {
    let eta: TimeInterval
    let distance: Double
    let timestamp: Date
    var trafficCondition: TrafficCondition?

    var isExpired: Bool {
        isExpired(at: Date())
    }

    func isExpired(at date: Date) -> Bool {
        date.timeIntervalSince(timestamp) > 300  // 5 minutes
    }
}

// MARK: - NotificationService Extension

extension NotificationService {
    /// Send notification when a member is approaching a place
    func notifyApproaching(memberName: String, placeName: String, eta: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(memberName) is almost there"
        content.body = "\(memberName) will arrive at \(placeName) in \(eta)"
        content.sound = .default
        content.categoryIdentifier = "APPROACHING"
        content.userInfo = [
            "type": "approaching",
            "memberName": memberName,
            "placeName": placeName
        ]

        let request = UNNotificationRequest(
            identifier: "approaching_\(memberName)_\(placeName)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                logger.error("Failed to send approaching notification: \(error.localizedDescription)")
            }
        }
    }
}
