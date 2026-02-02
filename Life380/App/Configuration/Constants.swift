import Foundation
import CoreLocation

/// App-wide constants
enum Constants {
    // MARK: - Animation Durations
    enum Animation {
        static let fast: Double = 0.15
        static let standard: Double = 0.25
        static let slow: Double = 0.35
        static let spring: Double = 0.5
    }

    // MARK: - Map Constants
    enum Map {
        static let defaultZoomLevel: Double = 0.01
        static let closeZoomLevel: Double = 0.005
        static let cityZoomLevel: Double = 0.1
        static let defaultRegionRadius: CLLocationDistance = 1000
        static let annotationCalloutWidth: CGFloat = 280
    }

    // MARK: - UI Sizes
    enum UI {
        static let avatarSizeSmall: CGFloat = 32
        static let avatarSizeMedium: CGFloat = 44
        static let avatarSizeLarge: CGFloat = 64
        static let avatarSizeXLarge: CGFloat = 80

        static let buttonHeight: CGFloat = 56
        static let inputHeight: CGFloat = 52
        static let tabBarHeight: CGFloat = 49

        static let iconSizeSmall: CGFloat = 16
        static let iconSizeMedium: CGFloat = 24
        static let iconSizeLarge: CGFloat = 32
    }

    // MARK: - Notification Names
    enum NotificationName {
        static let joinCircleDeepLink = Notification.Name("joinCircleDeepLink")
        static let locationUpdated = Notification.Name("locationUpdated")
        static let sosTriggered = Notification.Name("sosTriggered")
        static let circleUpdated = Notification.Name("circleUpdated")
    }

    // MARK: - UserDefaults Keys
    enum UserDefaultsKey {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let lastSelectedCircleId = "lastSelectedCircleId"
        static let locationSharingEnabled = "locationSharingEnabled"
        static let notificationsEnabled = "notificationsEnabled"
        static let biometricAuthEnabled = "biometricAuthEnabled"
    }

    // MARK: - Keychain Keys
    enum KeychainKey {
        static let userToken = "com.life380.userToken"
        static let refreshToken = "com.life380.refreshToken"
    }

    // MARK: - Deep Link Paths
    enum DeepLink {
        static let scheme = "life380"
        static let joinPath = "join"
        static let sosPath = "sos"
    }
}
