import SwiftUI
import CoreLocation

struct FamilyMember: Identifiable {
    let id = UUID()
    let name: String
    let latitude: Double
    let longitude: Double
    let lastLocation: String
    let lastUpdated: String
    let batteryLevel: Int
    let color: Color

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }

    var batteryIcon: String {
        switch batteryLevel {
        case 0...20: return "0"
        case 21...50: return "25"
        case 51...75: return "50"
        case 76...99: return "75"
        default: return "100"
        }
    }

    var batteryColor: Color {
        switch batteryLevel {
        case 0...20: return .red
        case 21...50: return .orange
        default: return .green
        }
    }
}

extension FamilyMember {
    static let sampleMembers: [FamilyMember] = [
        FamilyMember(
            name: "Mom",
            latitude: 37.7749,
            longitude: -122.4194,
            lastLocation: "Home",
            lastUpdated: "2 min ago",
            batteryLevel: 85,
            color: .pink
        ),
        FamilyMember(
            name: "Dad",
            latitude: 37.7849,
            longitude: -122.4094,
            lastLocation: "Work",
            lastUpdated: "5 min ago",
            batteryLevel: 42,
            color: .blue
        ),
        FamilyMember(
            name: "Sarah",
            latitude: 37.7649,
            longitude: -122.4294,
            lastLocation: "School",
            lastUpdated: "1 min ago",
            batteryLevel: 18,
            color: .purple
        )
    ]
}
