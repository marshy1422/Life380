import Foundation
import FirebaseFirestore
import CoreImage.CIFilterBuiltins
import UIKit

struct FamilyCircle: Identifiable, Codable {
    let id: String
    var name: String
    let createdBy: String
    var memberIds: [String]
    let inviteCode: String
    let createdAt: Date

    var dictionary: [String: Any] {
        [
            "id": id,
            "name": name,
            "createdBy": createdBy,
            "memberIds": memberIds,
            "inviteCode": inviteCode,
            "createdAt": createdAt
        ]
    }

    // MARK: - Computed Properties

    /// Number of members in the circle
    var memberCount: Int {
        memberIds.count
    }

    /// Whether the current user is the creator/admin
    func isAdmin(userId: String) -> Bool {
        createdBy == userId
    }

    /// Deep link URL for joining this circle
    var joinURL: URL? {
        URL(string: "life380://join?code=\(inviteCode)")
    }

    /// Shareable text for inviting members
    var shareText: String {
        "Join my Life380 circle \"\(name)\"! Download Life380 and use code: \(inviteCode)"
    }

    // MARK: - QR Code Generation

    /// Generate a QR code image for this circle's invite code
    func generateQRCode(size: CGFloat = 200) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        // Encode the deep link URL in the QR code
        let urlString = "life380://join?code=\(inviteCode)"
        filter.message = Data(urlString.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        // Scale the QR code to the desired size
        let scale = size / outputImage.extent.size.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    init(id: String, name: String, createdBy: String, memberIds: [String], inviteCode: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdBy = createdBy
        self.memberIds = memberIds
        self.inviteCode = inviteCode
        self.createdAt = createdAt
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
        self.createdBy = createdBy
        self.memberIds = memberIds
        self.inviteCode = inviteCode

        if let timestamp = dictionary["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else if let date = dictionary["createdAt"] as? Date {
            self.createdAt = date
        } else {
            self.createdAt = Date()
        }
    }
}
