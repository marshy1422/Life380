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
