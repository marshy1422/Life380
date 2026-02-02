import Foundation
import CoreLocation

/// Confidence level for location precision
enum LocationConfidence: String, Codable, CaseIterable {
    case excellent = "excellent"   // < 5m accuracy (GPS with clear sky)
    case high = "high"             // 5-15m accuracy (GPS or fused)
    case medium = "medium"         // 15-50m accuracy (WiFi-assisted)
    case low = "low"               // 50-100m accuracy (WiFi or degraded GPS)
    case approximate = "approximate"  // > 100m accuracy (cell tower)

    var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .high: return "Precise"
        case .medium: return "Good"
        case .low: return "Fair"
        case .approximate: return "Estimated"
        }
    }

    var shortName: String {
        switch self {
        case .excellent: return "±\(Int(accuracyRange.upperBound))m"
        case .high: return "±\(Int(accuracyRange.upperBound))m"
        case .medium: return "±\(Int(accuracyRange.upperBound))m"
        case .low: return "±\(Int(accuracyRange.upperBound))m"
        case .approximate: return ">100m"
        }
    }

    var description: String {
        switch self {
        case .excellent: return "GPS with clear sky view"
        case .high: return "Strong GPS or fused location"
        case .medium: return "WiFi-assisted positioning"
        case .low: return "Limited GPS or WiFi signal"
        case .approximate: return "Cell tower triangulation"
        }
    }

    var accuracyRange: ClosedRange<Double> {
        switch self {
        case .excellent: return 0...5
        case .high: return 5...15
        case .medium: return 15...50
        case .low: return 50...100
        case .approximate: return 100...Double.infinity
        }
    }

    var color: String {
        switch self {
        case .excellent: return "green"
        case .high: return "blue"
        case .medium: return "teal"
        case .low: return "orange"
        case .approximate: return "red"
        }
    }

    var iconName: String {
        switch self {
        case .excellent: return "location.fill.viewfinder"
        case .high: return "location.fill"
        case .medium: return "location"
        case .low: return "location.slash"
        case .approximate: return "location.slash.fill"
        }
    }

    /// Numeric score from 0-100 for UI display (progress bars, etc.)
    var score: Int {
        switch self {
        case .excellent: return 100
        case .high: return 85
        case .medium: return 65
        case .low: return 40
        case .approximate: return 15
        }
    }

    init(horizontalAccuracy: CLLocationAccuracy) {
        switch horizontalAccuracy {
        case ..<5:
            self = .excellent
        case 5..<15:
            self = .high
        case 15..<50:
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
