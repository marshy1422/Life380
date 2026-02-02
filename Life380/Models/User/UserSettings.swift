import Foundation

/// User-specific settings and preferences
struct UserSettings: Codable {
    // MARK: - Location Settings
    var isLocationSharingEnabled: Bool
    var locationUpdateFrequency: LocationUpdateFrequency
    var precisionSharingEnabled: Bool

    // MARK: - Notification Settings
    var notificationsEnabled: Bool
    var sosNotificationsEnabled: Bool
    var arrivalNotificationsEnabled: Bool
    var departureNotificationsEnabled: Bool
    var lowBatteryNotificationsEnabled: Bool

    // MARK: - Privacy Settings
    var showPreciseLocation: Bool
    var shareFloorLevel: Bool
    var shareBatteryLevel: Bool

    // MARK: - Security Settings
    var biometricAuthEnabled: Bool
    var requireAuthOnLaunch: Bool

    // MARK: - Default Values

    static var `default`: UserSettings {
        UserSettings(
            isLocationSharingEnabled: true,
            locationUpdateFrequency: .normal,
            precisionSharingEnabled: true,
            notificationsEnabled: true,
            sosNotificationsEnabled: true,
            arrivalNotificationsEnabled: true,
            departureNotificationsEnabled: true,
            lowBatteryNotificationsEnabled: true,
            showPreciseLocation: true,
            shareFloorLevel: true,
            shareBatteryLevel: true,
            biometricAuthEnabled: false,
            requireAuthOnLaunch: false
        )
    }

    // MARK: - Dictionary Conversion

    var dictionary: [String: Any] {
        [
            "isLocationSharingEnabled": isLocationSharingEnabled,
            "locationUpdateFrequency": locationUpdateFrequency.rawValue,
            "precisionSharingEnabled": precisionSharingEnabled,
            "notificationsEnabled": notificationsEnabled,
            "sosNotificationsEnabled": sosNotificationsEnabled,
            "arrivalNotificationsEnabled": arrivalNotificationsEnabled,
            "departureNotificationsEnabled": departureNotificationsEnabled,
            "lowBatteryNotificationsEnabled": lowBatteryNotificationsEnabled,
            "showPreciseLocation": showPreciseLocation,
            "shareFloorLevel": shareFloorLevel,
            "shareBatteryLevel": shareBatteryLevel,
            "biometricAuthEnabled": biometricAuthEnabled,
            "requireAuthOnLaunch": requireAuthOnLaunch
        ]
    }

    init(
        isLocationSharingEnabled: Bool = true,
        locationUpdateFrequency: LocationUpdateFrequency = .normal,
        precisionSharingEnabled: Bool = true,
        notificationsEnabled: Bool = true,
        sosNotificationsEnabled: Bool = true,
        arrivalNotificationsEnabled: Bool = true,
        departureNotificationsEnabled: Bool = true,
        lowBatteryNotificationsEnabled: Bool = true,
        showPreciseLocation: Bool = true,
        shareFloorLevel: Bool = true,
        shareBatteryLevel: Bool = true,
        biometricAuthEnabled: Bool = false,
        requireAuthOnLaunch: Bool = false
    ) {
        self.isLocationSharingEnabled = isLocationSharingEnabled
        self.locationUpdateFrequency = locationUpdateFrequency
        self.precisionSharingEnabled = precisionSharingEnabled
        self.notificationsEnabled = notificationsEnabled
        self.sosNotificationsEnabled = sosNotificationsEnabled
        self.arrivalNotificationsEnabled = arrivalNotificationsEnabled
        self.departureNotificationsEnabled = departureNotificationsEnabled
        self.lowBatteryNotificationsEnabled = lowBatteryNotificationsEnabled
        self.showPreciseLocation = showPreciseLocation
        self.shareFloorLevel = shareFloorLevel
        self.shareBatteryLevel = shareBatteryLevel
        self.biometricAuthEnabled = biometricAuthEnabled
        self.requireAuthOnLaunch = requireAuthOnLaunch
    }

    init?(dictionary: [String: Any]) {
        self.isLocationSharingEnabled = dictionary["isLocationSharingEnabled"] as? Bool ?? true
        if let frequencyRaw = dictionary["locationUpdateFrequency"] as? String,
           let frequency = LocationUpdateFrequency(rawValue: frequencyRaw) {
            self.locationUpdateFrequency = frequency
        } else {
            self.locationUpdateFrequency = .normal
        }
        self.precisionSharingEnabled = dictionary["precisionSharingEnabled"] as? Bool ?? true
        self.notificationsEnabled = dictionary["notificationsEnabled"] as? Bool ?? true
        self.sosNotificationsEnabled = dictionary["sosNotificationsEnabled"] as? Bool ?? true
        self.arrivalNotificationsEnabled = dictionary["arrivalNotificationsEnabled"] as? Bool ?? true
        self.departureNotificationsEnabled = dictionary["departureNotificationsEnabled"] as? Bool ?? true
        self.lowBatteryNotificationsEnabled = dictionary["lowBatteryNotificationsEnabled"] as? Bool ?? true
        self.showPreciseLocation = dictionary["showPreciseLocation"] as? Bool ?? true
        self.shareFloorLevel = dictionary["shareFloorLevel"] as? Bool ?? true
        self.shareBatteryLevel = dictionary["shareBatteryLevel"] as? Bool ?? true
        self.biometricAuthEnabled = dictionary["biometricAuthEnabled"] as? Bool ?? false
        self.requireAuthOnLaunch = dictionary["requireAuthOnLaunch"] as? Bool ?? false
    }
}

/// Location update frequency options
enum LocationUpdateFrequency: String, Codable, CaseIterable {
    case realtime = "realtime"   // Updates as frequently as possible
    case normal = "normal"       // Updates every 30 seconds
    case batterySaver = "battery_saver"  // Updates every 5 minutes

    var displayName: String {
        switch self {
        case .realtime: return "Real-time"
        case .normal: return "Normal"
        case .batterySaver: return "Battery Saver"
        }
    }

    var description: String {
        switch self {
        case .realtime: return "Continuous updates for maximum accuracy"
        case .normal: return "Updates every 30 seconds"
        case .batterySaver: return "Updates every 5 minutes to save battery"
        }
    }

    var intervalSeconds: TimeInterval {
        switch self {
        case .realtime: return 5
        case .normal: return 30
        case .batterySaver: return 300
        }
    }
}
