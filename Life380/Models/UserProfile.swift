import Foundation
import CoreLocation
import SwiftUI
import FirebaseFirestore

struct UserProfile: Identifiable, Codable {
    let id: String
    let email: String
    var displayName: String
    var photoURL: String?
    var latitude: Double
    var longitude: Double
    var lastUpdated: Date
    var batteryLevel: Int
    var isLocationSharing: Bool
    var circleIds: [String]
    var horizontalAccuracy: Double?  // Precision tracking
    var floor: Int?                  // Floor level from barometer

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var initials: String {
        let components = displayName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    var lastUpdatedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }

    var batteryIcon: String {
        switch batteryLevel {
        case 0...20: return "battery.0"
        case 21...50: return "battery.25"
        case 51...75: return "battery.50"
        case 76...99: return "battery.75"
        default: return "battery.100"
        }
    }

    var batteryColor: Color {
        switch batteryLevel {
        case 0...20: return .red
        case 21...50: return .orange
        default: return .green
        }
    }

    var color: Color {
        // Generate consistent color from user ID
        let hash = id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }

    /// Accuracy description for display
    var accuracyText: String? {
        guard let accuracy = horizontalAccuracy else { return nil }
        if accuracy < 10 {
            return "Precise"
        } else if accuracy < 50 {
            return "Good"
        } else if accuracy < 100 {
            return "Approximate"
        } else {
            return "Estimated"
        }
    }

    /// Whether this location is considered precise enough to trust
    var isPrecise: Bool {
        guard let accuracy = horizontalAccuracy else { return false }
        return accuracy < 50
    }

    /// Floor display name
    var floorDisplayName: String? {
        guard let floor = floor else { return nil }
        if floor == 0 {
            return "Ground floor"
        } else if floor > 0 {
            return "Floor \(floor)"
        } else {
            return "Basement \(abs(floor))"
        }
    }

    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "email": email,
            "displayName": displayName,
            "latitude": latitude,
            "longitude": longitude,
            "lastUpdated": lastUpdated,
            "batteryLevel": batteryLevel,
            "isLocationSharing": isLocationSharing
        ]
        if let photoURL = photoURL {
            dict["photoURL"] = photoURL
        }
        dict["circleIds"] = circleIds
        if let horizontalAccuracy = horizontalAccuracy {
            dict["horizontalAccuracy"] = horizontalAccuracy
        }
        if let floor = floor {
            dict["floor"] = floor
        }
        return dict
    }

    init(id: String, email: String, displayName: String, photoURL: String?, latitude: Double, longitude: Double, lastUpdated: Date, batteryLevel: Int, isLocationSharing: Bool, circleIds: [String] = [], horizontalAccuracy: Double? = nil, floor: Int? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.latitude = latitude
        self.longitude = longitude
        self.lastUpdated = lastUpdated
        self.batteryLevel = batteryLevel
        self.isLocationSharing = isLocationSharing
        self.circleIds = circleIds
        self.horizontalAccuracy = horizontalAccuracy
        self.floor = floor
    }

    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let email = dictionary["email"] as? String,
              let displayName = dictionary["displayName"] as? String,
              let latitude = dictionary["latitude"] as? Double,
              let longitude = dictionary["longitude"] as? Double,
              let batteryLevel = dictionary["batteryLevel"] as? Int,
              let isLocationSharing = dictionary["isLocationSharing"] as? Bool else {
            return nil
        }

        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = dictionary["photoURL"] as? String
        self.latitude = latitude
        self.longitude = longitude
        self.batteryLevel = batteryLevel
        self.isLocationSharing = isLocationSharing
        self.circleIds = dictionary["circleIds"] as? [String] ?? []
        self.horizontalAccuracy = dictionary["horizontalAccuracy"] as? Double
        self.floor = dictionary["floor"] as? Int

        if let timestamp = dictionary["lastUpdated"] as? Timestamp {
            self.lastUpdated = timestamp.dateValue()
        } else if let date = dictionary["lastUpdated"] as? Date {
            self.lastUpdated = date
        } else {
            self.lastUpdated = Date()
        }
    }
}
