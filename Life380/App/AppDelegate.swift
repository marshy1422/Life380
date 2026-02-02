import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import CoreLocation

/// AppDelegate for handling push notifications and app lifecycle events
class AppDelegate: NSObject, UIApplicationDelegate {

    /// Location manager for handling background location updates when app is relaunched
    private var backgroundLocationManager: CLLocationManager?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure push notifications
        configureNotifications(application)

        // Check if app was launched due to a location event (app was terminated)
        if launchOptions?[.location] != nil {
            AppLogger.log("App launched from location event - restarting location monitoring", level: .info)
            restartBackgroundLocationMonitoring()
        }

        return true
    }

    // MARK: - Background Location

    /// Restart location monitoring when app is relaunched from terminated state
    private func restartBackgroundLocationMonitoring() {
        backgroundLocationManager = CLLocationManager()
        backgroundLocationManager?.delegate = self
        backgroundLocationManager?.allowsBackgroundLocationUpdates = true
        backgroundLocationManager?.pausesLocationUpdatesAutomatically = false

        // Resume significant location change monitoring
        backgroundLocationManager?.startMonitoringSignificantLocationChanges()
    }

    // MARK: - Push Notifications

    private func configureNotifications(_ application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self

        // Register for remote notifications
        application.registerForRemoteNotifications()
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Pass device token to Firebase
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AppLogger.log("Failed to register for remote notifications: \(error.localizedDescription)", level: .error)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Handle notification actions
        handleNotificationResponse(response, userInfo: userInfo)

        completionHandler()
    }

    private func handleNotificationResponse(_ response: UNNotificationResponse, userInfo: [AnyHashable: Any]) {
        let actionIdentifier = response.actionIdentifier

        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            handleNotificationTap(userInfo: userInfo)

        case UNNotificationDismissActionIdentifier:
            // User dismissed the notification
            break

        default:
            // Handle custom actions
            handleCustomAction(actionIdentifier, userInfo: userInfo)
        }
    }

    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        // Handle navigation based on notification type
        if let type = userInfo["type"] as? String {
            switch type {
            case "sos":
                NotificationCenter.default.post(name: Constants.NotificationName.sosTriggered, object: nil, userInfo: userInfo)
            case "circle_update":
                NotificationCenter.default.post(name: Constants.NotificationName.circleUpdated, object: nil, userInfo: userInfo)
            case "location":
                NotificationCenter.default.post(name: Constants.NotificationName.locationUpdated, object: nil, userInfo: userInfo)
            default:
                break
            }
        }
    }

    private func handleCustomAction(_ action: String, userInfo: [AnyHashable: Any]) {
        // Handle custom notification actions
        AppLogger.log("Custom action: \(action)", level: .debug)
    }
}

// MARK: - CLLocationManagerDelegate (Background Location)

extension AppDelegate: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Filter out old or inaccurate locations
        let age = -location.timestamp.timeIntervalSinceNow
        guard age < 60, location.horizontalAccuracy >= 0, location.horizontalAccuracy < 500 else {
            return
        }

        AppLogger.log("Background location update: \(location.coordinate.latitude), \(location.coordinate.longitude)", level: .debug)

        // Upload location to Firestore in background
        Task {
            await uploadBackgroundLocation(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AppLogger.log("Background location error: \(error.localizedDescription)", level: .error)
    }

    /// Upload location when app is running in background or was relaunched
    private func uploadBackgroundLocation(_ location: CLLocation) async {
        // Get battery level
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = Int(UIDevice.current.batteryLevel * 100)

        await FirestoreService.shared.updateUserLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            batteryLevel: max(0, batteryLevel),
            accuracy: location.horizontalAccuracy
        )
    }
}
