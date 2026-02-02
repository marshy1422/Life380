import Foundation
import UserNotifications
import UIKit
import os.log

private let logger = Logger(subsystem: "com.life380.app", category: "Notifications")

/// Backward compatibility alias
typealias NotificationService = PushNotificationService

/// Handles local notifications for geofence events and other alerts
@MainActor
class PushNotificationService: ObservableObject {
    static let shared = PushNotificationService()

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

    // MARK: - Driving Alerts

    /// Send notification when speeding is detected
    func notifySpeedAlert(speed: Double, limit: Double) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Speed Alert"
        content.body = "You're traveling at \(Int(speed)) km/h. Please drive safely."
        content.sound = .default
        content.categoryIdentifier = "SPEED_ALERT"
        content.userInfo = [
            "type": "speed_alert",
            "speed": speed,
            "limit": limit
        ]

        let request = UNNotificationRequest(
            identifier: "speed_alert_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                logger.error("Failed to send speed notification: \(error.localizedDescription)")
            }
        }
    }

    /// Send notification when harsh driving is detected
    func notifyHarshDriving(type: String, speed: Double) {
        let content = UNMutableNotificationContent()

        switch type {
        case "hard_braking":
            content.title = "⚠️ Hard Braking Detected"
            content.body = "Harsh braking at \(Int(speed * 3.6)) km/h. Drive defensively."
        case "rapid_acceleration":
            content.title = "⚠️ Rapid Acceleration"
            content.body = "Aggressive acceleration detected. Drive smoothly."
        default:
            content.title = "⚠️ Driving Alert"
            content.body = "Unusual driving pattern detected."
        }

        content.sound = .default
        content.categoryIdentifier = "DRIVING_ALERT"

        let request = UNNotificationRequest(
            identifier: "driving_alert_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                logger.error("Failed to send driving notification: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Circle Member Arrival/Departure Notifications

    /// Notify when a circle member arrives at a place
    func notifyMemberArrived(memberName: String, placeName: String, placeIcon: String = "mappin") {
        let content = UNMutableNotificationContent()
        content.title = "\(memberName) arrived"
        content.body = "\(memberName) has arrived at \(placeName)"
        content.sound = .default
        content.categoryIdentifier = "MEMBER_ARRIVAL"
        content.userInfo = [
            "type": "member_arrival",
            "memberName": memberName,
            "placeName": placeName
        ]

        let request = UNNotificationRequest(
            identifier: "member_arrival_\(memberName)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                logger.error("Failed to send arrival notification: \(error.localizedDescription)")
            } else {
                logger.info("Sent arrival notification: \(memberName) at \(placeName)")
            }
        }
    }

    /// Notify when a circle member leaves a place
    func notifyMemberDeparted(memberName: String, placeName: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(memberName) left"
        content.body = "\(memberName) has left \(placeName)"
        content.sound = .default
        content.categoryIdentifier = "MEMBER_DEPARTURE"
        content.userInfo = [
            "type": "member_departure",
            "memberName": memberName,
            "placeName": placeName
        ]

        let request = UNNotificationRequest(
            identifier: "member_departure_\(memberName)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                logger.error("Failed to send departure notification: \(error.localizedDescription)")
            } else {
                logger.info("Sent departure notification: \(memberName) from \(placeName)")
            }
        }
    }

    /// Notify when a member starts their commute
    func notifyMemberCommute(memberName: String, fromPlace: String, toPlace: String, eta: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(memberName) on the way"
        content.body = "\(memberName) left \(fromPlace) heading to \(toPlace). ETA: \(eta)"
        content.sound = .default
        content.categoryIdentifier = "MEMBER_COMMUTE"
        content.userInfo = [
            "type": "member_commute",
            "memberName": memberName,
            "from": fromPlace,
            "to": toPlace,
            "eta": eta
        ]

        let request = UNNotificationRequest(
            identifier: "member_commute_\(memberName)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                logger.error("Failed to send commute notification: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Scheduled Notifications

    /// Schedule a reminder for when a member should leave to arrive on time
    func scheduleLeaveReminder(memberName: String, destination: String, leaveByTime: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Time to leave"
        content.body = "Leave now to reach \(destination) on time"
        content.sound = .default
        content.categoryIdentifier = "LEAVE_REMINDER"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(leaveByTime.timeIntervalSinceNow, 1),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "leave_reminder_\(destination)",
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                logger.error("Failed to schedule leave reminder: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Notification Management

    func clearAllNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        notificationCenter.removeAllPendingNotificationRequests()
    }

    func clearNotificationsForPlace(placeId: String) {
        Task {
            let notifications = await notificationCenter.deliveredNotifications()
            let idsToRemove = notifications
                .filter { $0.request.content.userInfo["placeId"] as? String == placeId }
                .map { $0.request.identifier }

            notificationCenter.removeDeliveredNotifications(withIdentifiers: idsToRemove)
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
