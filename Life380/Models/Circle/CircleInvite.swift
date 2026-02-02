import Foundation
import FirebaseFirestore

/// Represents a pending circle invitation
struct CircleInvite: Identifiable, Codable {
    let id: String
    let circleId: String
    let circleName: String
    var circleEmoji: String?
    let inviteCode: String
    let invitedBy: String
    let invitedByName: String
    let createdAt: Date
    let expiresAt: Date?
    var usedBy: String?
    var usedAt: Date?
    var isActive: Bool

    // MARK: - Computed Properties

    var isExpired: Bool {
        guard let expires = expiresAt else { return false }
        return Date() > expires
    }

    var isUsed: Bool {
        usedBy != nil
    }

    var isValid: Bool {
        guard isActive else { return false }
        guard !isUsed else { return false }
        guard !isExpired else { return false }
        return true
    }

    var timeRemaining: String {
        guard let expires = expiresAt else { return "No expiration" }
        let remaining = expires.timeIntervalSince(Date())
        if remaining <= 0 { return "Expired" }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2

        return formatter.string(from: remaining) ?? "Expired"
    }

    var deepLink: URL? {
        URL(string: "life380://join?code=\(inviteCode)")
    }

    var shareLink: URL? {
        URL(string: "https://life380.app/join/\(inviteCode)")
    }

    var shareText: String {
        "Join my Life380 circle \"\(circleName)\"! Use invite code: \(inviteCode) or tap: life380://join?code=\(inviteCode)"
    }

    // MARK: - Dictionary Conversion

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

        if let circleEmoji = circleEmoji { dict["circleEmoji"] = circleEmoji }
        if let expiresAt = expiresAt { dict["expiresAt"] = expiresAt }
        if let usedBy = usedBy { dict["usedBy"] = usedBy }
        if let usedAt = usedAt { dict["usedAt"] = usedAt }

        return dict
    }

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        circleId: String,
        circleName: String,
        circleEmoji: String? = nil,
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
        self.circleEmoji = circleEmoji
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
        self.circleEmoji = dictionary["circleEmoji"] as? String
        self.inviteCode = inviteCode
        self.invitedBy = invitedBy
        self.invitedByName = invitedByName
        self.isActive = isActive
        self.usedBy = dictionary["usedBy"] as? String

        // Parse dates
        if let timestamp = dictionary["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else if let date = dictionary["createdAt"] as? Date {
            self.createdAt = date
        } else {
            self.createdAt = Date()
        }

        if let timestamp = dictionary["expiresAt"] as? Timestamp {
            self.expiresAt = timestamp.dateValue()
        } else {
            self.expiresAt = dictionary["expiresAt"] as? Date
        }

        if let timestamp = dictionary["usedAt"] as? Timestamp {
            self.usedAt = timestamp.dateValue()
        } else {
            self.usedAt = dictionary["usedAt"] as? Date
        }
    }
}

// MARK: - Backward Compatibility

extension CircleInvite {
    /// Alias for backward compatibility
    var deepLinkURL: URL? { deepLink }
}
