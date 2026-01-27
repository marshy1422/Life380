import Foundation
import UserNotifications
import UIKit
import os.log

private let logger = Logger(subsystem: "com.life380.app", category: "Notifications")

/// Handles local notifications for geofence events and other alerts
@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized: Bool = false
    @Published var pendingNotifications: [UNNotificationRequest] = []

    let notificationCenter = UNUserNotificationCenter.current()

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
            }
            logger.info("Notification authorization: \(granted ? "granted" : "denied")")
            return granted
        } catch {
            logger.error("Notification authorization error: \(error.localizedDescription)")
            return false
        }
    }

    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Geofence Notifications

    /// Send notification when user enters a place
    func notifyGeofenceEntry(placeName: String, placeId: String) {
        let content = UNMutableNotificationContent()
        content.title = "📍 Arrived at \(placeName)"
        content.body = "You've arrived at \(placeName)"
        content.sound = .default
        content.categoryIdentifier = "GEOFENCE_ENTRY"
        content.userInfo = [
            "type": "geofence_entry",
            "placeId": placeId,
            "placeName": placeName
        ]

        // Add a subtle badge
        content.badge = nil

        let request = UNNotificationRequest(
            identifier: "geofence_entry_\(placeId)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        notificationCenter.add(request) { error in
            if let error = error {
                logger.error("Failed to send entry notification: \(error.localizedDescription)")
            } else {
                logger.info("Sent arrival notification for \(placeName)")
            }
        }
    }

    /// Send notification when user exits a place
    func notifyGeofenceExit(placeName: String, placeId: String) {
        let content = UNMutableNotificationContent()
        content.title = "Left \(placeName)"
        content.body = "You've left \(placeName)"
        content.sound = .default
        content.categoryIdentifier = "GEOFENCE_EXIT"
        content.userInfo = [
            "type": "geofence_exit",
            "placeId": placeId,
            "placeName": placeName
        ]

        let request = UNNotificationRequest(
            identifier: "geofence_exit_\(placeId)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        notificationCenter.add(request) { error in
            if let error = error {
                logger.error("Failed to send exit notification: \(error.localizedDescription)")
            } else {
                logger.info("Sent departure notification for \(placeName)")
            }
        }
    }

    /// Send notification to circle members when someone arrives/leaves
    func notifyCircleMemberArrival(memberName: String, placeName: String, arrived: Bool) {
        let content = UNMutableNotificationContent()

        if arrived {
            content.title = "\(memberName) arrived"
            content.body = "\(memberName) arrived at \(placeName)"
        } else {
            content.title = "\(memberName) left"
            content.body = "\(memberName) left \(placeName)"
        }

        content.sound = .default
        content.categoryIdentifier = "MEMBER_LOCATION"

        let request = UNNotificationRequest(
            identifier: "member_\(arrived ? "arrival" : "departure")_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                logger.error("Failed to send member notification: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Battery Alerts

    /// Send notification when a family member has low battery
    func notifyLowBattery(memberName: String, batteryLevel: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🔋 Low Battery Alert"
        content.body = "\(memberName)'s phone is at \(batteryLevel)%"
        content.sound = .default
        content.categoryIdentifier = "LOW_BATTERY"

        let request = UNNotificationRequest(
            identifier: "low_battery_\(memberName)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                logger.error("Failed to send battery notification: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Notification Management

    func clearAllNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        notificationCenter.removeAllPendingNotificationRequests()
    }

    func clearNotificationsForPlace(placeId: String) {
        notificationCenter.getDeliveredNotifications { notifications in
            let idsToRemove = notifications
                .filter { $0.request.content.userInfo["placeId"] as? String == placeId }
                .map { $0.request.identifier }

            self.notificationCenter.removeDeliveredNotifications(withIdentifiers: idsToRemove)
        }
    }

    // MARK: - Notification Categories (for actions)

    func setupNotificationCategories() {
        // Entry notification actions
        let viewMapAction = UNNotificationAction(
            identifier: "VIEW_MAP",
            title: "View on Map",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: []
        )

        let entryCategory = UNNotificationCategory(
            identifier: "GEOFENCE_ENTRY",
            actions: [viewMapAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let exitCategory = UNNotificationCategory(
            identifier: "GEOFENCE_EXIT",
            actions: [viewMapAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let memberCategory = UNNotificationCategory(
            identifier: "MEMBER_LOCATION",
            actions: [viewMapAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let batteryCategory = UNNotificationCategory(
            identifier: "LOW_BATTERY",
            actions: [dismissAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([
            entryCategory,
            exitCategory,
            memberCategory,
            batteryCategory
        ])
    }
}
