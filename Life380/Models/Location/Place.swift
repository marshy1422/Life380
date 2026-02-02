import SwiftUI
import CoreLocation

struct Place: Identifiable, Codable, Equatable {
    var id: String
    let name: String
    let address: String
    let icon: String
    let colorHex: String
    let notificationsEnabled: Bool
    let latitude: Double
    let longitude: Double
    let radius: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    var dictionary: [String: Any] {
        [
            "id": id,
            "name": name,
            "address": address,
            "icon": icon,
            "colorHex": colorHex,
            "notificationsEnabled": notificationsEnabled,
            "latitude": latitude,
            "longitude": longitude,
            "radius": radius
        ]
    }

    init(id: String = UUID().uuidString, name: String, address: String, icon: String, color: Color, notificationsEnabled: Bool, latitude: Double, longitude: Double, radius: Double = 100) {
        self.id = id
        self.name = name
        self.address = address
        self.icon = icon
        self.colorHex = color.toHex() ?? "#007AFF"
        self.notificationsEnabled = notificationsEnabled
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
    }

    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let name = dictionary["name"] as? String,
              let address = dictionary["address"] as? String,
              let icon = dictionary["icon"] as? String,
              let colorHex = dictionary["colorHex"] as? String,
              let notificationsEnabled = dictionary["notificationsEnabled"] as? Bool,
              let latitude = dictionary["latitude"] as? Double,
              let longitude = dictionary["longitude"] as? Double else {
            return nil
        }

        self.id = id
        self.name = name
        self.address = address
        self.icon = icon
        self.colorHex = colorHex
        self.notificationsEnabled = notificationsEnabled
        self.latitude = latitude
        self.longitude = longitude
        self.radius = dictionary["radius"] as? Double ?? 100
    }
}

extension Place {
    static let samplePlaces: [Place] = [
        Place(
            name: "Home",
            address: "123 Main St, San Francisco, CA",
            icon: "house.fill",
            color: .blue,
            notificationsEnabled: true,
            latitude: 37.7749,
            longitude: -122.4194
        ),
        Place(
            name: "Work",
            address: "456 Market St, San Francisco, CA",
            icon: "building.2.fill",
            color: .green,
            notificationsEnabled: true,
            latitude: 37.7849,
            longitude: -122.4094
        ),
        Place(
            name: "School",
            address: "789 Education Blvd, San Francisco, CA",
            icon: "graduationcap.fill",
            color: .orange,
            notificationsEnabled: true,
            latitude: 37.7649,
            longitude: -122.4294
        )
    ]
}

// MARK: - Color Extensions

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])

        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}
