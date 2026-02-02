import Foundation
import FirebaseFirestore
import FirebaseAuth
import UIKit
import CoreImage.CIFilterBuiltins

/// Service for managing circle invitations
@MainActor
class InviteService: ObservableObject {
    static let shared = InviteService()

    private let db = Firestore.firestore()

    @Published var pendingInvites: [CircleInvite] = []
    @Published var isLoading = false
    @Published var error: String?

    private init() {}

    // MARK: - Create Invite

    /// Create a new invite for a circle
    func createInvite(
        for circle: FamilyCircle,
        expiresIn hours: Int? = nil
    ) async throws -> CircleInvite {
        guard let userId = Auth.auth().currentUser?.uid,
              let userName = FirestoreService.shared.currentUserProfile?.displayName else {
            throw InviteError.notAuthenticated
        }

        let expiresAt: Date? = hours.map { Date().addingTimeInterval(TimeInterval($0 * 3600)) }

        let invite = CircleInvite(
            circleId: circle.id,
            circleName: circle.name,
            inviteCode: circle.inviteCode,
            invitedBy: userId,
            invitedByName: userName,
            expiresAt: expiresAt
        )

        // Store in Firestore for tracking (optional - the invite code is on the circle itself)
        try await db.collection("invites").document(invite.id).setData(invite.dictionary)

        return invite
    }

    // MARK: - Validate Invite

    /// Check if an invite code is valid and get circle info
    func validateInviteCode(_ code: String) async throws -> (circle: FamilyCircle, memberCount: Int) {
        let cleanCode = code.trimmingCharacters(in: .whitespaces).uppercased()

        guard cleanCode.count == 6 else {
            throw InviteError.invalidCode
        }

        let snapshot = try await db.collection("circles")
            .whereField("inviteCode", isEqualTo: cleanCode)
            .getDocuments()

        guard let doc = snapshot.documents.first,
              let circle = FamilyCircle(dictionary: doc.data()) else {
            throw InviteError.circleNotFound
        }

        return (circle, circle.memberCount)
    }

    // MARK: - QR Code Generation

    /// Generate a QR code for an invite
    func generateQRCode(for invite: CircleInvite, size: CGFloat = 250) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        guard let url = invite.deepLinkURL else { return nil }
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scale = size / outputImage.extent.size.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    /// Generate a QR code directly from an invite code
    func generateQRCode(forCode code: String, size: CGFloat = 250) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        let urlString = "life380://join?code=\(code)"
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

    // MARK: - Share Functionality

    /// Get items for sharing an invite
    func shareItems(for circle: FamilyCircle) -> [Any] {
        var items: [Any] = [circle.shareText]

        // Add QR code image if we can generate it
        if let qrImage = circle.generateQRCode(size: 300) {
            items.append(qrImage)
        }

        return items
    }

    // MARK: - Track Invite Usage

    /// Mark an invite as used
    func markInviteUsed(inviteId: String, byUserId: String) async throws {
        try await db.collection("invites").document(inviteId).updateData([
            "usedBy": byUserId,
            "usedAt": FieldValue.serverTimestamp(),
            "isActive": false
        ])
    }

    // MARK: - Regenerate Invite Code

    /// Generate a new invite code for a circle (admin only)
    func regenerateInviteCode(for circleId: String) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw InviteError.notAuthenticated
        }

        // Verify user is admin of the circle
        let circleDoc = try await db.collection("circles").document(circleId).getDocument()
        guard let data = circleDoc.data(),
              let createdBy = data["createdBy"] as? String,
              createdBy == userId else {
            throw InviteError.notAuthorized
        }

        // Generate new code
        let newCode = generateInviteCode()

        // Update circle with new code
        try await db.collection("circles").document(circleId).updateData([
            "inviteCode": newCode
        ])

        return newCode
    }

    // MARK: - Helpers

    private func generateInviteCode() -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in characters.randomElement() })
    }
}

// MARK: - Errors

enum InviteError: LocalizedError {
    case notAuthenticated
    case notAuthorized
    case invalidCode
    case circleNotFound
    case inviteExpired
    case alreadyMember

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to create invites"
        case .notAuthorized:
            return "You don't have permission to do this"
        case .invalidCode:
            return "Invalid invite code format"
        case .circleNotFound:
            return "No circle found with this invite code"
        case .inviteExpired:
            return "This invite has expired"
        case .alreadyMember:
            return "You're already a member of this circle"
        }
    }
}
