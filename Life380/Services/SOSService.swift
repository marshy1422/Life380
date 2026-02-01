import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI
#if os(iOS)
import UIKit
#endif
import os.log

private let logger = Logger(subsystem: "com.life380.app", category: "SOS")

/// Represents an SOS alert
struct SOSAlert: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let latitude: Double
    let longitude: Double
    let batteryLevel: Int
    let timestamp: Date
    let message: String?
    var isActive: Bool
    var resolvedAt: Date?
    var resolvedBy: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "userId": userId,
            "userName": userName,
            "latitude": latitude,
            "longitude": longitude,
            "batteryLevel": batteryLevel,
            "timestamp": timestamp,
            "isActive": isActive
        ]
        if let message = message {
            dict["message"] = message
        }
        if let resolvedAt = resolvedAt {
            dict["resolvedAt"] = resolvedAt
        }
        if let resolvedBy = resolvedBy {
            dict["resolvedBy"] = resolvedBy
        }
        return dict
    }

    init(id: String = UUID().uuidString,
         userId: String,
         userName: String,
         latitude: Double,
         longitude: Double,
         batteryLevel: Int,
         timestamp: Date = Date(),
         message: String? = nil,
         isActive: Bool = true,
         resolvedAt: Date? = nil,
         resolvedBy: String? = nil) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.latitude = latitude
        self.longitude = longitude
        self.batteryLevel = batteryLevel
        self.timestamp = timestamp
        self.message = message
        self.isActive = isActive
        self.resolvedAt = resolvedAt
        self.resolvedBy = resolvedBy
    }

    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let userId = dictionary["userId"] as? String,
              let userName = dictionary["userName"] as? String,
              let latitude = dictionary["latitude"] as? Double,
              let longitude = dictionary["longitude"] as? Double,
              let batteryLevel = dictionary["batteryLevel"] as? Int,
              let isActive = dictionary["isActive"] as? Bool else {
            return nil
        }

        self.id = id
        self.userId = userId
        self.userName = userName
        self.latitude = latitude
        self.longitude = longitude
        self.batteryLevel = batteryLevel
        self.isActive = isActive
        self.message = dictionary["message"] as? String
        self.resolvedBy = dictionary["resolvedBy"] as? String

        if let timestamp = dictionary["timestamp"] as? Timestamp {
            self.timestamp = timestamp.dateValue()
        } else {
            self.timestamp = Date()
        }

        if let resolvedAt = dictionary["resolvedAt"] as? Timestamp {
            self.resolvedAt = resolvedAt.dateValue()
        } else {
            self.resolvedAt = nil
        }
    }
}

/// Service for handling SOS alerts
@MainActor
class SOSService: ObservableObject {
    static let shared = SOSService()

    private let db = Firestore.firestore()

    // Published state
    @Published var isSOSActive: Bool = false
    @Published var currentAlert: SOSAlert?
    @Published var circleAlerts: [SOSAlert] = []
    @Published var isSending: Bool = false

    // Countdown state
    @Published var countdownActive: Bool = false
    @Published var countdownRemaining: Int = 0
    @Published var countdownTotal: Int = 10 // Default 10 second countdown

    // Location streaming during SOS
    @Published var streamedLocations: [CLLocationCoordinate2D] = []
    private var locationStreamTimer: Timer?
    private let locationStreamInterval: TimeInterval = 5 // Stream location every 5 seconds

    // Listener
    private var alertsListener: ListenerRegistration?
    private var countdownTimer: Timer?

    // Settings
    @AppStorage("sosCountdownDuration") var sosCountdownDuration: Int = 10
    @AppStorage("sosAutoCallEmergency") var autoCallEmergency: Bool = false

    private init() {}

    // MARK: - Countdown SOS

    /// Start SOS countdown - gives user time to cancel
    func startCountdown(
        location: CLLocationCoordinate2D,
        batteryLevel: Int,
        message: String? = nil
    ) {
        countdownTotal = sosCountdownDuration
        countdownRemaining = sosCountdownDuration
        countdownActive = true

        // Vibrate to alert user
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            Task { @MainActor in
                self.countdownRemaining -= 1

                // Haptic feedback each second
                #if os(iOS)
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                #endif

                if self.countdownRemaining <= 0 {
                    timer.invalidate()
                    self.countdownActive = false

                    // Trigger SOS
                    do {
                        try await self.triggerSOS(
                            location: location,
                            batteryLevel: batteryLevel,
                            message: message
                        )
                    } catch {
                        logger.error("Failed to trigger SOS after countdown: \(error)")
                    }
                }
            }
        }
    }

    /// Cancel the countdown before SOS triggers
    func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownActive = false
        countdownRemaining = 0

        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif

        logger.info("SOS countdown cancelled by user")
    }

    // MARK: - Trigger SOS

    /// Trigger an SOS alert - sends to all circle members
    func triggerSOS(
        location: CLLocationCoordinate2D,
        batteryLevel: Int,
        message: String? = nil
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw SOSError.notAuthenticated
        }

        guard let circleId = FirestoreService.shared.currentCircleId else {
            throw SOSError.noCircle
        }

        guard let userProfile = FirestoreService.shared.currentUserProfile else {
            throw SOSError.noProfile
        }

        isSending = true

        let alert = SOSAlert(
            userId: userId,
            userName: userProfile.displayName,
            latitude: location.latitude,
            longitude: location.longitude,
            batteryLevel: batteryLevel,
            message: message
        )

        // Save to Firestore
        try await db.collection("circles")
            .document(circleId)
            .collection("sosAlerts")
            .document(alert.id)
            .setData(alert.dictionary)

        // Update local state
        currentAlert = alert
        isSOSActive = true
        isSending = false

        logger.notice("🆘 SOS TRIGGERED by \(userProfile.displayName) at (\(location.latitude), \(location.longitude))")

        // Send local notification to self (confirmation)
        NotificationService.shared.notifySOSSent()

        // Start location streaming
        startLocationStreaming(alertId: alert.id, circleId: circleId)

        // The other circle members will receive the alert via Firestore listener
        // In a production app, you'd also send push notifications via FCM
    }

    // MARK: - Location Streaming

    /// Start streaming location updates during active SOS
    private func startLocationStreaming(alertId: String, circleId: String) {
        streamedLocations.removeAll()

        locationStreamTimer = Timer.scheduledTimer(withTimeInterval: locationStreamInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                await self.streamCurrentLocation(alertId: alertId, circleId: circleId)
            }
        }

        // Also stream immediately
        Task {
            await streamCurrentLocation(alertId: alertId, circleId: circleId)
        }

        logger.info("Started location streaming for SOS \(alertId)")
    }

    /// Stop location streaming
    private func stopLocationStreaming() {
        locationStreamTimer?.invalidate()
        locationStreamTimer = nil
        logger.info("Stopped location streaming")
    }

    /// Stream current location to Firestore
    private func streamCurrentLocation(alertId: String, circleId: String) async {
        // Get current location from the user profile
        guard let userProfile = FirestoreService.shared.currentUserProfile else { return }

        let coordinate = userProfile.coordinate
        let accuracy = userProfile.horizontalAccuracy ?? 10.0

        streamedLocations.append(coordinate)

        // Update location in Firestore
        let locationUpdate: [String: Any] = [
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "accuracy": accuracy,
            "speed": 0,
            "timestamp": FieldValue.serverTimestamp()
        ]

        do {
            try await db.collection("circles")
                .document(circleId)
                .collection("sosAlerts")
                .document(alertId)
                .updateData([
                    "latitude": coordinate.latitude,
                    "longitude": coordinate.longitude,
                    "lastUpdate": FieldValue.serverTimestamp()
                ])

            // Also add to location history subcollection
            try await db.collection("circles")
                .document(circleId)
                .collection("sosAlerts")
                .document(alertId)
                .collection("locationHistory")
                .addDocument(data: locationUpdate)

            logger.debug("Streamed location: (\(coordinate.latitude), \(coordinate.longitude))")
        } catch {
            logger.error("Failed to stream location: \(error)")
        }
    }

    // MARK: - Cancel SOS

    /// Cancel/resolve an active SOS alert
    func cancelSOS(resolvedBy: String? = nil) async throws {
        guard let alert = currentAlert else { return }
        guard let circleId = FirestoreService.shared.currentCircleId else { return }

        // Stop location streaming
        stopLocationStreaming()

        let resolverId = resolvedBy ?? Auth.auth().currentUser?.uid ?? "unknown"

        try await db.collection("circles")
            .document(circleId)
            .collection("sosAlerts")
            .document(alert.id)
            .updateData([
                "isActive": false,
                "resolvedAt": FieldValue.serverTimestamp(),
                "resolvedBy": resolverId,
                "locationCount": streamedLocations.count
            ])

        currentAlert = nil
        isSOSActive = false
        streamedLocations.removeAll()

        // Haptic feedback
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif

        logger.info("✅ SOS RESOLVED for alert \(alert.id) with \(self.streamedLocations.count) location updates")
    }

    // MARK: - Listen for Circle SOS Alerts

    /// Start listening for SOS alerts in the current circle
    func listenToCircleAlerts(circleId: String) {
        // Remove existing listener
        alertsListener?.remove()

        alertsListener = db.collection("circles")
            .document(circleId)
            .collection("sosAlerts")
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }

                let alerts = documents.compactMap { SOSAlert(dictionary: $0.data()) }
                self.circleAlerts = alerts

                // Check for new alerts from other users
                let currentUserId = Auth.auth().currentUser?.uid
                for alert in alerts {
                    if alert.userId != currentUserId {
                        // Someone else triggered SOS - notify!
                        NotificationService.shared.notifySOSReceived(
                            fromName: alert.userName,
                            latitude: alert.latitude,
                            longitude: alert.longitude
                        )
                    }
                }
            }
    }

    /// Stop listening to alerts
    func stopListening() {
        alertsListener?.remove()
        alertsListener = nil
    }

    // MARK: - Check-In System

    /// Send a "I'm safe" check-in to circle
    func sendCheckIn() async throws {
        guard let userId = Auth.auth().currentUser?.uid,
              let circleId = FirestoreService.shared.currentCircleId,
              let userProfile = FirestoreService.shared.currentUserProfile else {
            return
        }

        let checkIn: [String: Any] = [
            "userId": userId,
            "userName": userProfile.displayName,
            "timestamp": FieldValue.serverTimestamp(),
            "type": "safe"
        ]

        try await db.collection("circles")
            .document(circleId)
            .collection("checkIns")
            .addDocument(data: checkIn)

        logger.info("✅ Check-in sent by \(userProfile.displayName)")
    }
}

// MARK: - Errors

enum SOSError: LocalizedError {
    case notAuthenticated
    case noCircle
    case noProfile
    case sendFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to send an SOS"
        case .noCircle:
            return "You must be in a circle to send an SOS"
        case .noProfile:
            return "Could not load your profile"
        case .sendFailed:
            return "Failed to send SOS alert"
        }
    }
}

// MARK: - NotificationService Extension

extension NotificationService {
    /// Confirmation that SOS was sent
    func notifySOSSent() {
        let content = UNMutableNotificationContent()
        content.title = "🆘 SOS Alert Sent"
        content.body = "Your emergency alert has been sent to your circle"
        content.sound = .default
        content.categoryIdentifier = "SOS_SENT"

        let request = UNNotificationRequest(
            identifier: "sos_sent_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
    }

    /// Received SOS from another circle member
    func notifySOSReceived(fromName: String, latitude: Double, longitude: Double) {
        let content = UNMutableNotificationContent()
        content.title = "🆘 EMERGENCY: \(fromName) needs help!"
        content.body = "\(fromName) has triggered an SOS alert. Tap to see their location."
        content.sound = .defaultCritical  // Loud alert sound
        content.categoryIdentifier = "SOS_RECEIVED"
        content.userInfo = [
            "type": "sos",
            "latitude": latitude,
            "longitude": longitude,
            "fromName": fromName
        ]
        content.interruptionLevel = .critical  // Bypasses Do Not Disturb

        let request = UNNotificationRequest(
            identifier: "sos_received_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                logger.error("Failed to send SOS notification: \(error.localizedDescription)")
            } else {
                logger.notice("🆘 SOS notification sent for \(fromName)")
            }
        }
    }
}
