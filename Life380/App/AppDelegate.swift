import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

/// AppDelegate for handling push notifications and app lifecycle events
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure push notifications
        configureNotifications(application)

        return true
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
