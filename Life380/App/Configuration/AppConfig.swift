import Foundation

/// App-wide configuration and feature flags
struct AppConfig {
    // MARK: - Feature Flags
    static let enablePrecisionLocation = true
    static let enableSOSFeature = true
    static let enableInsights = true
    static let enableBiometricAuth = true
    static let enableQRCodeScanning = true

    // MARK: - App Settings
    static let appName = "Life380"
    static let appScheme = "life380"
    static let supportEmail = "support@life380.app"

    // MARK: - Location Settings
    static let defaultGeofenceRadius: Double = 100 // meters
    static let minimumLocationAccuracy: Double = 100 // meters
    static let locationUpdateInterval: TimeInterval = 30 // seconds
    static let staleLocationThreshold: TimeInterval = 60 // seconds

    // MARK: - Circle Settings
    static let maxCircleMembers = 20
    static let inviteCodeLength = 6
    static let inviteExpirationDays = 7

    // MARK: - Battery Thresholds
    static let lowBatteryThreshold = 20
    static let criticalBatteryThreshold = 10

    // MARK: - API Limits
    static let maxPlaces = 50
    static let maxCircles = 10
    static let locationHistoryDays = 30
}
