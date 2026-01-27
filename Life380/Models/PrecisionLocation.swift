import Foundation
import CoreLocation

/// Confidence level for location precision
enum LocationConfidence: String, Codable {
    case high = "high"        // < 10m accuracy
    case medium = "medium"    // 10-50m accuracy
    case low = "low"          // 50-100m accuracy
    case approximate = "approximate"  // > 100m accuracy

    var displayName: String {
        switch self {
        case .high: return "Precise"
        case .medium: return "Good"
        case .low: return "Approximate"
        case .approximate: return "Estimated"
        }
    }

    init(horizontalAccuracy: CLLocationAccuracy) {
        switch horizontalAccuracy {
        case ..<10:
            self = .high
        case 10..<50:
            self = .medium
        case 50..<100:
            self = .low
        default:
            self = .approximate
        }
    }
}

/// Source of the location fix
enum LocationSource: String, Codable {
    case gnss = "gnss"           // GPS/GLONASS/Galileo satellite
    case wifi = "wifi"           // Wi-Fi based positioning
    case cellular = "cellular"   // Cell tower triangulation
    case fused = "fused"         // Multiple sources combined
    case cached = "cached"       // Previously known location
    case unknown = "unknown"

    var icon: String {
        switch self {
        case .gnss: return "satellite.fill"
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .fused: return "location.fill"
        case .cached: return "clock.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

/// Enhanced location model with precision metadata
struct PrecisionLocation: Identifiable, Codable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let horizontalAccuracy: Double
    let verticalAccuracy: Double?
    let course: Double?          // Direction of travel (0-360)
    let speed: Double?           // Meters per second
    let timestamp: Date
    let source: LocationSource
    let floor: Int?              // Building floor if available

    // Computed properties
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var confidence: LocationConfidence {
        LocationConfidence(horizontalAccuracy: horizontalAccuracy)
    }

    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 60 // Older than 1 minute
    }

    var staleness: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }

    var accuracyDescription: String {
        if horizontalAccuracy < 10 {
            return "within \(Int(horizontalAccuracy))m"
        } else if horizontalAccuracy < 100 {
            return "within \(Int(horizontalAccuracy))m"
        } else if horizontalAccuracy < 1000 {
            return "within \(Int(horizontalAccuracy / 100) * 100)m"
        } else {
            return "within \(String(format: "%.1f", horizontalAccuracy / 1000))km"
        }
    }

    /// Confidence radius for UI display (clamped for visual clarity)
    var confidenceRadius: Double {
        min(max(horizontalAccuracy, 5), 200) // Clamp between 5m and 200m for UI
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        horizontalAccuracy: Double,
        verticalAccuracy: Double? = nil,
        course: Double? = nil,
        speed: Double? = nil,
        timestamp: Date = Date(),
        source: LocationSource = .unknown,
        floor: Int? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.course = course
        self.speed = speed
        self.timestamp = timestamp
        self.source = source
        self.floor = floor
    }

    /// Initialize from CLLocation
    init(from clLocation: CLLocation, source: LocationSource = .unknown) {
        self.id = UUID()
        self.latitude = clLocation.coordinate.latitude
        self.longitude = clLocation.coordinate.longitude
        self.altitude = clLocation.altitude
        self.horizontalAccuracy = clLocation.horizontalAccuracy
        self.verticalAccuracy = clLocation.verticalAccuracy >= 0 ? clLocation.verticalAccuracy : nil
        self.course = clLocation.course >= 0 ? clLocation.course : nil
        self.speed = clLocation.speed >= 0 ? clLocation.speed : nil
        self.timestamp = clLocation.timestamp
        self.source = source
        self.floor = clLocation.floor?.level
    }

    // MARK: - Distance Calculations

    func distance(to other: PrecisionLocation) -> CLLocationDistance {
        let loc1 = CLLocation(latitude: latitude, longitude: longitude)
        let loc2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return loc1.distance(from: loc2)
    }

    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let loc1 = CLLocation(latitude: latitude, longitude: longitude)
        let loc2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return loc1.distance(from: loc2)
    }

    // MARK: - Validation

    /// Check if this location meets minimum accuracy threshold
    func meetsAccuracyThreshold(_ threshold: Double) -> Bool {
        horizontalAccuracy <= threshold && horizontalAccuracy >= 0
    }

    /// Check if location is valid (positive accuracy, reasonable coordinates)
    var isValid: Bool {
        horizontalAccuracy >= 0 &&
        latitude >= -90 && latitude <= 90 &&
        longitude >= -180 && longitude <= 180
    }
}

// MARK: - Equatable

extension PrecisionLocation: Equatable {
    static func == (lhs: PrecisionLocation, rhs: PrecisionLocation) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension PrecisionLocation: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
