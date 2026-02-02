import Foundation
import FirebaseFirestore

/// Represents a pending circle invitation
struct CircleInvite: Identifiable, Codable {
    let id: String
    let circleId: String
    let circleName: String
    let inviteCode: String
    let invitedBy: String           // User ID who created the invite
    let invitedByName: String       // Display name for UI
    let createdAt: Date
    let expiresAt: Date?            // Optional expiration
    var usedBy: String?             // User ID who used the invite
    var usedAt: Date?
    var isActive: Bool

    /// Check if invite is still valid
    var isValid: Bool {
        guard isActive else { return false }
        guard usedBy == nil else { return false }
        if let expires = expiresAt, Date() > expires {
            return false
        }
        return true
    }

    /// Time remaining until expiration
    var timeRemaining: String? {
        guard let expires = expiresAt else { return nil }
        let remaining = expires.timeIntervalSince(Date())
        if remaining <= 0 { return "Expired" }

        let hours = Int(remaining / 3600)
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 24 {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s") left"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else {
            return "\(minutes)m left"
        }
    }

    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "circleId": circleId,
            "circleName": circleName,
            "inviteCode": inviteCode,
            "invitedBy": invitedBy,
            "invitedByName": invitedByName,
            "createdAt": createdAt,
            "isActive": isActive
        ]
        if let expiresAt = expiresAt {
            dict["expiresAt"] = expiresAt
        }
        if let usedBy = usedBy {
            dict["usedBy"] = usedBy
        }
        if let usedAt = usedAt {
            dict["usedAt"] = usedAt
        }
        return dict
    }

    init(
        id: String = UUID().uuidString,
        circleId: String,
        circleName: String,
        inviteCode: String,
        invitedBy: String,
        invitedByName: String,
        createdAt: Date = Date(),
        expiresAt: Date? = nil,
        usedBy: String? = nil,
        usedAt: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.circleId = circleId
        self.circleName = circleName
        self.inviteCode = inviteCode
        self.invitedBy = invitedBy
        self.invitedByName = invitedByName
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.usedBy = usedBy
        self.usedAt = usedAt
        self.isActive = isActive
    }

    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let circleId = dictionary["circleId"] as? String,
              let circleName = dictionary["circleName"] as? String,
              let inviteCode = dictionary["inviteCode"] as? String,
              let invitedBy = dictionary["invitedBy"] as? String,
              let invitedByName = dictionary["invitedByName"] as? String,
              let isActive = dictionary["isActive"] as? Bool else {
            return nil
        }

        self.id = id
        self.circleId = circleId
        self.circleName = circleName
        self.inviteCode = inviteCode
        self.invitedBy = invitedBy
        self.invitedByName = invitedByName
        self.isActive = isActive
        self.usedBy = dictionary["usedBy"] as? String

        // Parse dates
        if let timestamp = dictionary["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }

        if let timestamp = dictionary["expiresAt"] as? Timestamp {
            self.expiresAt = timestamp.dateValue()
        } else {
            self.expiresAt = nil
        }

        if let timestamp = dictionary["usedAt"] as? Timestamp {
            self.usedAt = timestamp.dateValue()
        } else {
            self.usedAt = nil
        }
    }
}

// MARK: - Invite Link Generation

extension CircleInvite {
    /// Generate a deep link URL for this invite
    var deepLinkURL: URL? {
        URL(string: "life380://join?code=\(inviteCode)")
    }

    /// Generate a shareable text message
    var shareText: String {
        "Join my Life380 circle \"\(circleName)\"! Use invite code: \(inviteCode) or tap: life380://join?code=\(inviteCode)"
    }
}
