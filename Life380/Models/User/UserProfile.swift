import Foundation
import CoreLocation
import SwiftUI
import FirebaseFirestore

// MARK: - Battery Status

enum BatteryStatus {
    case normal, low, critical, charging, unknown

    var color: Color {
        switch self {
        case .normal, .charging: return .green
        case .low: return .orange
        case .critical: return .red
        case .unknown: return .gray
        }
    }

    var icon: String {
        switch self {
        case .normal: return "battery.75"
        case .low: return "battery.25"
        case .critical: return "battery.0"
        case .charging: return "battery.100.bolt"
        case .unknown: return "battery.0"
        }
    }
}

// MARK: - User Profile

struct UserProfile: Identifiable, Codable, Equatable {
    let id: String
    let email: String
    var displayName: String
    var firstName: String?
    var lastName: String?
    var photoURL: String?
    var phoneNumber: String?

    // Location
    var latitude: Double?
    var longitude: Double?
    var currentAddress: String?
    var lastUpdated: Date
    var horizontalAccuracy: Double?
    var floor: Int?

    // Device
    var batteryLevel: Int
    var isCharging: Bool?
    var deviceModel: String?

    // Settings
    var isLocationSharing: Bool
    var notificationsEnabled: Bool?

    // Metadata
    var circleIds: [String]
    var createdAt: Date?
    var lastActiveAt: Date?

    // MARK: - Computed Properties

    var fullName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        // Reject "Null Island" coordinates (0,0) as invalid
        if lat == 0 && lon == 0 { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var hasValidLocation: Bool {
        coordinate != nil
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

    var locationAge: String? {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }

    var batteryIcon: String {
        if isCharging == true {
            return "battery.100.bolt"
        }
        switch batteryLevel {
        case 0...20: return "battery.0"
        case 21...50: return "battery.25"
        case 51...75: return "battery.50"
        case 76...99: return "battery.75"
        default: return "battery.100"
        }
    }

    var batteryColor: Color {
        if isCharging == true { return .green }
        switch batteryLevel {
        case 0...20: return .red
        case 21...50: return .orange
        default: return .green
        }
    }

    var batteryStatus: BatteryStatus {
        if isCharging == true { return .charging }
        switch batteryLevel {
        case 0...15: return .critical
        case 16...30: return .low
        default: return .normal
        }
    }

    var color: Color {
        let hash = id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }

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

    var isPrecise: Bool {
        guard let accuracy = horizontalAccuracy else { return false }
        return accuracy < 50
    }

    var floorDisplayName: String? {
        guard let floor = floor else { return nil }
        // Only show floor for reasonable values (-2 to +20)
        // Values outside this range are likely barometer noise, not actual floors
        guard floor >= -2 && floor <= 20 else { return nil }
        if floor == 0 {
            return nil // Don't show "Ground floor" - it's the default
        } else if floor > 0 {
            return "Floor \(floor)"
        } else {
            return "Basement \(abs(floor))"
        }
    }

    // MARK: - Dictionary Conversion

    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "email": email,
            "displayName": displayName,
            "lastUpdated": lastUpdated,
            "batteryLevel": batteryLevel,
            "isLocationSharing": isLocationSharing,
            "circleIds": circleIds
        ]

        if let firstName = firstName { dict["firstName"] = firstName }
        if let lastName = lastName { dict["lastName"] = lastName }
        if let photoURL = photoURL { dict["photoURL"] = photoURL }
        if let phoneNumber = phoneNumber { dict["phoneNumber"] = phoneNumber }
        if let latitude = latitude { dict["latitude"] = latitude }
        if let longitude = longitude { dict["longitude"] = longitude }
        if let currentAddress = currentAddress { dict["currentAddress"] = currentAddress }
        if let horizontalAccuracy = horizontalAccuracy { dict["horizontalAccuracy"] = horizontalAccuracy }
        if let floor = floor { dict["floor"] = floor }
        if let isCharging = isCharging { dict["isCharging"] = isCharging }
        if let deviceModel = deviceModel { dict["deviceModel"] = deviceModel }
        if let notificationsEnabled = notificationsEnabled { dict["notificationsEnabled"] = notificationsEnabled }
        if let createdAt = createdAt { dict["createdAt"] = createdAt }
        if let lastActiveAt = lastActiveAt { dict["lastActiveAt"] = lastActiveAt }

        return dict
    }

    // MARK: - Initialization

    init(
        id: String,
        email: String,
        displayName: String,
        firstName: String? = nil,
        lastName: String? = nil,
        photoURL: String? = nil,
        phoneNumber: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        currentAddress: String? = nil,
        lastUpdated: Date = Date(),
        horizontalAccuracy: Double? = nil,
        floor: Int? = nil,
        batteryLevel: Int = 100,
        isCharging: Bool? = nil,
        deviceModel: String? = nil,
        isLocationSharing: Bool = true,
        notificationsEnabled: Bool? = nil,
        circleIds: [String] = [],
        createdAt: Date? = nil,
        lastActiveAt: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.firstName = firstName
        self.lastName = lastName
        self.photoURL = photoURL
        self.phoneNumber = phoneNumber
        self.latitude = latitude
        self.longitude = longitude
        self.currentAddress = currentAddress
        self.lastUpdated = lastUpdated
        self.horizontalAccuracy = horizontalAccuracy
        self.floor = floor
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
        self.deviceModel = deviceModel
        self.isLocationSharing = isLocationSharing
        self.notificationsEnabled = notificationsEnabled
        self.circleIds = circleIds
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
    }

    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let email = dictionary["email"] as? String,
              let displayName = dictionary["displayName"] as? String,
              let batteryLevel = dictionary["batteryLevel"] as? Int,
              let isLocationSharing = dictionary["isLocationSharing"] as? Bool else {
            return nil
        }

        self.id = id
        self.email = email
        self.displayName = displayName
        self.firstName = dictionary["firstName"] as? String
        self.lastName = dictionary["lastName"] as? String
        self.photoURL = dictionary["photoURL"] as? String
        self.phoneNumber = dictionary["phoneNumber"] as? String
        self.latitude = dictionary["latitude"] as? Double
        self.longitude = dictionary["longitude"] as? Double
        self.currentAddress = dictionary["currentAddress"] as? String
        self.horizontalAccuracy = dictionary["horizontalAccuracy"] as? Double
        self.floor = dictionary["floor"] as? Int
        self.batteryLevel = batteryLevel
        self.isCharging = dictionary["isCharging"] as? Bool
        self.deviceModel = dictionary["deviceModel"] as? String
        self.isLocationSharing = isLocationSharing
        self.notificationsEnabled = dictionary["notificationsEnabled"] as? Bool
        self.circleIds = dictionary["circleIds"] as? [String] ?? []

        // Parse dates
        if let timestamp = dictionary["lastUpdated"] as? Timestamp {
            self.lastUpdated = timestamp.dateValue()
        } else if let date = dictionary["lastUpdated"] as? Date {
            self.lastUpdated = date
        } else {
            self.lastUpdated = Date()
        }

        if let timestamp = dictionary["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = dictionary["createdAt"] as? Date
        }

        if let timestamp = dictionary["lastActiveAt"] as? Timestamp {
            self.lastActiveAt = timestamp.dateValue()
        } else {
            self.lastActiveAt = dictionary["lastActiveAt"] as? Date
        }
    }

    // MARK: - Equatable

    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        // Include location fields so SwiftUI detects location updates
        lhs.id == rhs.id &&
        lhs.latitude == rhs.latitude &&
        lhs.longitude == rhs.longitude &&
        lhs.lastUpdated == rhs.lastUpdated &&
        lhs.batteryLevel == rhs.batteryLevel &&
        lhs.isLocationSharing == rhs.isLocationSharing
    }
}
