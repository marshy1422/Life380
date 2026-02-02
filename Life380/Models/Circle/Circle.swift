import Foundation
import FirebaseFirestore
import CoreImage.CIFilterBuiltins
import UIKit

struct FamilyCircle: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var emoji: String?
    let createdBy: String
    var memberIds: [String]
    var adminIds: [String]?
    let inviteCode: String
    let createdAt: Date
    var updatedAt: Date?

    // Settings
    var locationSharingRequired: Bool?
    var allowMemberInvites: Bool?

    // MARK: - Computed Properties

    var memberCount: Int {
        memberIds.count
    }

    /// Whether a user is the creator/owner
    func isOwner(_ userId: String) -> Bool {
        createdBy == userId
    }

    /// Whether a user is an admin (creator or in adminIds)
    func isAdmin(_ userId: String) -> Bool {
        if createdBy == userId { return true }
        return adminIds?.contains(userId) ?? false
    }

    /// Backward compatible isAdmin for old code
    func isAdmin(userId: String) -> Bool {
        isAdmin(userId)
    }

    /// Whether a user is a member
    func isMember(_ userId: String) -> Bool {
        memberIds.contains(userId)
    }

    /// Deep link URL for joining this circle
    var joinURL: URL? {
        URL(string: "life380://join?code=\(inviteCode)")
    }

    /// Universal link for App Store fallback
    var shareLink: URL? {
        URL(string: "https://life380.app/join/\(inviteCode)")
    }

    /// Shareable text for inviting members
    var shareText: String {
        "Join my Life380 circle \"\(name)\"! Download Life380 and use code: \(inviteCode)"
    }

    /// Display emoji or first letter
    var displayEmoji: String {
        emoji ?? String(name.prefix(1)).uppercased()
    }

    // MARK: - Dictionary Conversion

    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "name": name,
            "createdBy": createdBy,
            "memberIds": memberIds,
            "inviteCode": inviteCode,
            "createdAt": createdAt
        ]

        if let emoji = emoji { dict["emoji"] = emoji }
        if let adminIds = adminIds { dict["adminIds"] = adminIds }
        if let updatedAt = updatedAt { dict["updatedAt"] = updatedAt }
        if let locationSharingRequired = locationSharingRequired { dict["locationSharingRequired"] = locationSharingRequired }
        if let allowMemberInvites = allowMemberInvites { dict["allowMemberInvites"] = allowMemberInvites }

        return dict
    }

    // MARK: - QR Code Generation

    func generateQRCode(size: CGFloat = 200) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        let urlString = "life380://join?code=\(inviteCode)"
        filter.message = Data(urlString.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scale = size / outputImage.extent.size.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - Initialization

    init(
        id: String,
        name: String,
        emoji: String? = nil,
        createdBy: String,
        memberIds: [String],
        adminIds: [String]? = nil,
        inviteCode: String,
        createdAt: Date,
        updatedAt: Date? = nil,
        locationSharingRequired: Bool? = nil,
        allowMemberInvites: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.createdBy = createdBy
        self.memberIds = memberIds
        self.adminIds = adminIds ?? [createdBy]
        self.inviteCode = inviteCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.locationSharingRequired = locationSharingRequired
        self.allowMemberInvites = allowMemberInvites
    }

    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let name = dictionary["name"] as? String,
              let createdBy = dictionary["createdBy"] as? String,
              let memberIds = dictionary["memberIds"] as? [String],
              let inviteCode = dictionary["inviteCode"] as? String else {
            return nil
        }

        self.id = id
        self.name = name
        self.emoji = dictionary["emoji"] as? String
        self.createdBy = createdBy
        self.memberIds = memberIds
        self.adminIds = dictionary["adminIds"] as? [String]
        self.inviteCode = inviteCode
        self.locationSharingRequired = dictionary["locationSharingRequired"] as? Bool
        self.allowMemberInvites = dictionary["allowMemberInvites"] as? Bool

        // Parse dates
        if let timestamp = dictionary["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else if let date = dictionary["createdAt"] as? Date {
            self.createdAt = date
        } else {
            self.createdAt = Date()
        }

        if let timestamp = dictionary["updatedAt"] as? Timestamp {
            self.updatedAt = timestamp.dateValue()
        } else {
            self.updatedAt = dictionary["updatedAt"] as? Date
        }
    }

    // MARK: - Equatable

    static func == (lhs: FamilyCircle, rhs: FamilyCircle) -> Bool {
        lhs.id == rhs.id
    }
}

