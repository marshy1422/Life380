import Foundation
import CryptoKit
import FirebaseFirestore
import FirebaseAuth
import UIKit
import CoreImage.CIFilterBuiltins
import os.log

private let inviteLogger = Logger(subsystem: "com.life380.app", category: "SecureInvite")

// MARK: - Secure Invite Token

/// Cryptographically secure invite token
struct SecureInviteToken: Codable {
    let id: String
    let circleId: String
    let circleName: String
    let createdBy: String
    let createdByName: String
    let createdAt: Date
    let expiresAt: Date
    let maxUses: Int
    let usedCount: Int
    let signature: Data        // HMAC signature for tamper detection
    let requiresApproval: Bool // Admin must approve join request

    /// Token string for sharing (URL-safe base64)
    var tokenString: String {
        // Combine key data into shareable format
        let components = "\(id)|\(circleId)|\(expiresAt.timeIntervalSince1970)"
        return Data(components.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Short 6-character code for easy entry
    var shortCode: String {
        // Generate deterministic short code from token ID
        let hash = SHA256.hash(data: Data(id.utf8))
        let bytes = Array(hash.prefix(4))
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        var code = ""
        for byte in bytes {
            let index = Int(byte) % chars.count
            code.append(chars[chars.index(chars.startIndex, offsetBy: index)])
        }
        return String(code.prefix(6))
    }

    var isExpired: Bool {
        Date() > expiresAt
    }

    var isUsedUp: Bool {
        usedCount >= maxUses
    }

    var isValid: Bool {
        !isExpired && !isUsedUp
    }

    var deepLinkURL: URL? {
        URL(string: "life380://join?token=\(tokenString)")
    }

    var shareText: String {
        """
        Join my Life380 circle "\(circleName)"!

        Use code: \(shortCode)
        Or open: \(deepLinkURL?.absoluteString ?? "")

        Download Life380: https://life380.app
        """
    }
}

// MARK: - Join Request

/// Request to join a circle (when invite requires approval)
struct CircleJoinRequest: Codable, Identifiable {
    let id: String
    let circleId: String
    let userId: String
    let userName: String
    let userEmail: String
    let inviteTokenId: String
    let requestedAt: Date
    var status: JoinRequestStatus
    var reviewedBy: String?
    var reviewedAt: Date?
    var denialReason: String?

    enum JoinRequestStatus: String, Codable {
        case pending
        case approved
        case denied
        case expired
    }
}

// MARK: - Secure Invite Service

/// Service for creating and validating secure invites
@MainActor
class SecureInviteService: ObservableObject {
    static let shared = SecureInviteService()

    // MARK: - Published State

    @Published var pendingRequests: [CircleJoinRequest] = []
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Private Properties

    private let db = Firestore.firestore()
    private let signingKey: SymmetricKey
    private static let signingKeyKeychainKey = "com.life380.secureInvite.signingKey"

    // Rate limiting
    private var inviteCreationTimes: [String: [Date]] = [:] // circleId -> timestamps
    private let maxInvitesPerHour = 10

    private init() {
        // Retrieve or generate signing key from Keychain
        if let existingKeyData = try? KeychainManager.getData(forKey: Self.signingKeyKeychainKey) {
            self.signingKey = SymmetricKey(data: existingKeyData)
        } else {
            // Generate new key and store in Keychain
            let newKey = SymmetricKey(size: .bits256)
            let keyData = newKey.withUnsafeBytes { Data($0) }
            try? KeychainManager.save(keyData, forKey: Self.signingKeyKeychainKey)
            self.signingKey = newKey
        }
    }

    // MARK: - Create Secure Invite

    /// Create a new secure invite token
    func createInvite(
        for circleId: String,
        circleName: String,
        expiresIn hours: Int = 24,
        maxUses: Int = 1,
        requiresApproval: Bool = false
    ) async throws -> SecureInviteToken {
        guard let userId = Auth.auth().currentUser?.uid,
              let profile = try? await fetchCurrentUserProfile() else {
            throw SecureInviteError.notAuthenticated
        }

        // Rate limiting
        try checkRateLimit(for: circleId)

        // Verify user is admin of the circle
        let circleDoc = try await db.collection("circles").document(circleId).getDocument()
        guard let data = circleDoc.data(),
              let createdBy = data["createdBy"] as? String,
              let adminIds = data["adminIds"] as? [String],
              (createdBy == userId || adminIds.contains(userId)) else {
            throw SecureInviteError.notAuthorized
        }

        let tokenId = UUID().uuidString
        let expiresAt = Date().addingTimeInterval(TimeInterval(hours * 3600))

        // Create signature for tamper detection
        let signatureData = "\(tokenId)|\(circleId)|\(expiresAt.timeIntervalSince1970)".data(using: .utf8)!
        let signature = HMAC<SHA256>.authenticationCode(for: signatureData, using: signingKey)

        let token = SecureInviteToken(
            id: tokenId,
            circleId: circleId,
            circleName: circleName,
            createdBy: userId,
            createdByName: profile.displayName,
            createdAt: Date(),
            expiresAt: expiresAt,
            maxUses: maxUses,
            usedCount: 0,
            signature: Data(signature),
            requiresApproval: requiresApproval
        )

        // Store in Firestore
        try await db.collection("secure_invites").document(tokenId).setData([
            "id": tokenId,
            "circleId": circleId,
            "circleName": circleName,
            "createdBy": userId,
            "createdByName": profile.displayName,
            "createdAt": FieldValue.serverTimestamp(),
            "expiresAt": expiresAt,
            "maxUses": maxUses,
            "usedCount": 0,
            "shortCode": token.shortCode,
            "signature": signature,
            "requiresApproval": requiresApproval,
            "isActive": true
        ])

        // Update rate limit tracking
        recordInviteCreation(for: circleId)

        inviteLogger.info("Created secure invite \(tokenId) for circle \(circleId)")
        return token
    }

    // MARK: - Validate Invite

    /// Validate an invite by short code
    func validateInvite(shortCode: String) async throws -> SecureInviteToken {
        let cleanCode = shortCode.uppercased().trimmingCharacters(in: .whitespaces)

        guard cleanCode.count == 6 else {
            throw SecureInviteError.invalidCode
        }

        let snapshot = try await db.collection("secure_invites")
            .whereField("shortCode", isEqualTo: cleanCode)
            .whereField("isActive", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first,
              let token = try? parseInviteDocument(doc) else {
            throw SecureInviteError.inviteNotFound
        }

        // Validate token
        try validateToken(token)

        return token
    }

    /// Validate an invite by token string
    func validateInvite(tokenString: String) async throws -> SecureInviteToken {
        // Decode token string
        let paddedString = tokenString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .padding(toLength: ((tokenString.count + 3) / 4) * 4, withPad: "=", startingAt: 0)

        guard let data = Data(base64Encoded: paddedString),
              let components = String(data: data, encoding: .utf8)?.split(separator: "|"),
              components.count >= 2 else {
            throw SecureInviteError.invalidToken
        }

        let tokenId = String(components[0])

        let doc = try await db.collection("secure_invites").document(tokenId).getDocument()
        guard doc.exists, let token = try? parseInviteDocument(doc) else {
            throw SecureInviteError.inviteNotFound
        }

        try validateToken(token)

        return token
    }

    private func validateToken(_ token: SecureInviteToken) throws {
        // Check expiry
        guard !token.isExpired else {
            throw SecureInviteError.inviteExpired
        }

        // Check uses
        guard !token.isUsedUp else {
            throw SecureInviteError.inviteUsedUp
        }

        // Verify signature
        let signatureData = "\(token.id)|\(token.circleId)|\(token.expiresAt.timeIntervalSince1970)".data(using: .utf8)!
        let expectedSignature = HMAC<SHA256>.authenticationCode(for: signatureData, using: signingKey)

        guard Data(expectedSignature) == token.signature else {
            inviteLogger.error("Invalid signature for token \(token.id)")
            throw SecureInviteError.invalidSignature
        }
    }

    // MARK: - Accept Invite

    /// Accept an invite and join the circle
    func acceptInvite(_ token: SecureInviteToken) async throws {
        guard let userId = Auth.auth().currentUser?.uid,
              let profile = try? await fetchCurrentUserProfile() else {
            throw SecureInviteError.notAuthenticated
        }

        // Check if already a member
        let circleDoc = try await db.collection("circles").document(token.circleId).getDocument()
        guard let circleData = circleDoc.data(),
              let memberIds = circleData["memberIds"] as? [String] else {
            throw SecureInviteError.circleNotFound
        }

        if memberIds.contains(userId) {
            throw SecureInviteError.alreadyMember
        }

        // If approval required, create join request
        if token.requiresApproval {
            try await createJoinRequest(token: token, userId: userId, profile: profile)
            inviteLogger.info("Created join request for circle \(token.circleId)")
            return
        }

        // Direct join
        try await performJoin(circleId: token.circleId, userId: userId, tokenId: token.id)

        // Share encryption key with new member
        try await shareCircleKey(circleId: token.circleId, withUserId: userId)

        inviteLogger.info("User \(userId) joined circle \(token.circleId)")
    }

    private func createJoinRequest(token: SecureInviteToken, userId: String, profile: UserProfile) async throws {
        let requestId = UUID().uuidString
        let request = CircleJoinRequest(
            id: requestId,
            circleId: token.circleId,
            userId: userId,
            userName: profile.displayName,
            userEmail: profile.email,
            inviteTokenId: token.id,
            requestedAt: Date(),
            status: .pending
        )

        try await db.collection("circles").document(token.circleId)
            .collection("join_requests").document(requestId)
            .setData([
                "id": requestId,
                "circleId": token.circleId,
                "userId": userId,
                "userName": profile.displayName,
                "userEmail": profile.email,
                "inviteTokenId": token.id,
                "requestedAt": FieldValue.serverTimestamp(),
                "status": "pending"
            ])

        // Notify circle admins
        // TODO: Send push notification to admins
    }

    private func performJoin(circleId: String, userId: String, tokenId: String) async throws {
        let batch = db.batch()

        // Add user to circle
        let circleRef = db.collection("circles").document(circleId)
        batch.updateData([
            "memberIds": FieldValue.arrayUnion([userId])
        ], forDocument: circleRef)

        // Add circle to user
        let userRef = db.collection("users").document(userId)
        batch.updateData([
            "circleIds": FieldValue.arrayUnion([circleId])
        ], forDocument: userRef)

        // Increment invite usage
        let inviteRef = db.collection("secure_invites").document(tokenId)
        batch.updateData([
            "usedCount": FieldValue.increment(Int64(1))
        ], forDocument: inviteRef)

        try await batch.commit()
    }

    private func shareCircleKey(circleId: String, withUserId: String) async throws {
        // Get new member's public key
        let userDoc = try await db.collection("users").document(withUserId).getDocument()
        guard let publicKeyData = userDoc.data()?["publicKey"] as? Data,
              let publicKey = try? P256.KeyAgreement.PublicKey(rawRepresentation: publicKeyData) else {
            inviteLogger.warning("New member doesn't have public key - skipping key share")
            return
        }

        // Export circle key encrypted for new member
        let exportedKey = try CircleKeyManager.shared.exportKeyForMember(
            circleId: circleId,
            recipientPublicKey: publicKey
        )

        // Store exported key for member to retrieve
        try await db.collection("circles").document(circleId)
            .collection("member_keys").document(withUserId)
            .setData([
                "encryptedKey": exportedKey,
                "createdAt": FieldValue.serverTimestamp(),
                "keyVersion": CircleKeyManager.shared.currentKeyVersion(for: circleId)
            ])
    }

    // MARK: - Approve/Deny Join Requests

    /// Approve a join request (admin only)
    func approveJoinRequest(_ request: CircleJoinRequest) async throws {
        guard let adminId = Auth.auth().currentUser?.uid else {
            throw SecureInviteError.notAuthenticated
        }

        // Verify admin status
        let circleDoc = try await db.collection("circles").document(request.circleId).getDocument()
        guard let data = circleDoc.data(),
              let createdBy = data["createdBy"] as? String,
              let adminIds = data["adminIds"] as? [String],
              (createdBy == adminId || adminIds.contains(adminId)) else {
            throw SecureInviteError.notAuthorized
        }

        // Perform join
        try await performJoin(circleId: request.circleId, userId: request.userId, tokenId: request.inviteTokenId)

        // Share encryption key
        try await shareCircleKey(circleId: request.circleId, withUserId: request.userId)

        // Update request status
        try await db.collection("circles").document(request.circleId)
            .collection("join_requests").document(request.id)
            .updateData([
                "status": "approved",
                "reviewedBy": adminId,
                "reviewedAt": FieldValue.serverTimestamp()
            ])

        inviteLogger.info("Approved join request \(request.id)")
    }

    /// Deny a join request (admin only)
    func denyJoinRequest(_ request: CircleJoinRequest, reason: String?) async throws {
        guard let adminId = Auth.auth().currentUser?.uid else {
            throw SecureInviteError.notAuthenticated
        }

        // Verify admin status
        let circleDoc = try await db.collection("circles").document(request.circleId).getDocument()
        guard let data = circleDoc.data(),
              let createdBy = data["createdBy"] as? String,
              let adminIds = data["adminIds"] as? [String],
              (createdBy == adminId || adminIds.contains(adminId)) else {
            throw SecureInviteError.notAuthorized
        }

        try await db.collection("circles").document(request.circleId)
            .collection("join_requests").document(request.id)
            .updateData([
                "status": "denied",
                "reviewedBy": adminId,
                "reviewedAt": FieldValue.serverTimestamp(),
                "denialReason": reason ?? ""
            ])

        inviteLogger.info("Denied join request \(request.id)")
    }

    // MARK: - Revoke Invite

    /// Revoke an invite token (admin only)
    func revokeInvite(tokenId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw SecureInviteError.notAuthenticated
        }

        // Get invite to verify ownership
        let doc = try await db.collection("secure_invites").document(tokenId).getDocument()
        guard let data = doc.data(),
              let createdBy = data["createdBy"] as? String,
              let circleId = data["circleId"] as? String else {
            throw SecureInviteError.inviteNotFound
        }

        // Verify admin or creator
        let circleDoc = try await db.collection("circles").document(circleId).getDocument()
        guard let circleData = circleDoc.data(),
              let circleCreatedBy = circleData["createdBy"] as? String,
              let adminIds = circleData["adminIds"] as? [String],
              (createdBy == userId || circleCreatedBy == userId || adminIds.contains(userId)) else {
            throw SecureInviteError.notAuthorized
        }

        try await db.collection("secure_invites").document(tokenId).updateData([
            "isActive": false,
            "revokedAt": FieldValue.serverTimestamp(),
            "revokedBy": userId
        ])

        inviteLogger.info("Revoked invite \(tokenId)")
    }

    // MARK: - QR Code Generation

    /// Generate QR code for invite
    func generateQRCode(for token: SecureInviteToken, size: CGFloat = 250) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        guard let url = token.deepLinkURL else { return nil }
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "H" // High error correction for security

        guard let outputImage = filter.outputImage else { return nil }

        let scale = size / outputImage.extent.size.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - Rate Limiting

    private func checkRateLimit(for circleId: String) throws {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)

        // Clean old entries
        inviteCreationTimes[circleId]?.removeAll { $0 < oneHourAgo }

        let recentCount = inviteCreationTimes[circleId]?.count ?? 0
        if recentCount >= maxInvitesPerHour {
            throw SecureInviteError.rateLimitExceeded
        }
    }

    private func recordInviteCreation(for circleId: String) {
        if inviteCreationTimes[circleId] == nil {
            inviteCreationTimes[circleId] = []
        }
        inviteCreationTimes[circleId]?.append(Date())
    }

    // MARK: - Helpers

    private func parseInviteDocument(_ doc: DocumentSnapshot) throws -> SecureInviteToken {
        guard let data = doc.data(),
              let id = data["id"] as? String,
              let circleId = data["circleId"] as? String,
              let circleName = data["circleName"] as? String,
              let createdBy = data["createdBy"] as? String,
              let createdByName = data["createdByName"] as? String,
              let maxUses = data["maxUses"] as? Int,
              let usedCount = data["usedCount"] as? Int,
              let signature = data["signature"] as? Data else {
            throw SecureInviteError.invalidInviteData
        }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        let expiresAt: Date
        if let timestamp = data["expiresAt"] as? Timestamp {
            expiresAt = timestamp.dateValue()
        } else if let date = data["expiresAt"] as? Date {
            expiresAt = date
        } else {
            throw SecureInviteError.invalidInviteData
        }

        let requiresApproval = data["requiresApproval"] as? Bool ?? false

        return SecureInviteToken(
            id: id,
            circleId: circleId,
            circleName: circleName,
            createdBy: createdBy,
            createdByName: createdByName,
            createdAt: createdAt,
            expiresAt: expiresAt,
            maxUses: maxUses,
            usedCount: usedCount,
            signature: signature,
            requiresApproval: requiresApproval
        )
    }

    private func fetchCurrentUserProfile() async throws -> UserProfile {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw SecureInviteError.notAuthenticated
        }

        let doc = try await db.collection("users").document(userId).getDocument()
        guard let data = doc.data(), let profile = UserProfile(dictionary: data) else {
            throw SecureInviteError.profileNotFound
        }

        return profile
    }
}

// MARK: - Secure Invite Errors

enum SecureInviteError: LocalizedError {
    case notAuthenticated
    case notAuthorized
    case invalidCode
    case invalidToken
    case invalidSignature
    case inviteNotFound
    case inviteExpired
    case inviteUsedUp
    case alreadyMember
    case circleNotFound
    case rateLimitExceeded
    case invalidInviteData
    case profileNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be signed in"
        case .notAuthorized: return "You don't have permission to do this"
        case .invalidCode: return "Invalid invite code format"
        case .invalidToken: return "Invalid invite token"
        case .invalidSignature: return "This invite link appears to be tampered with"
        case .inviteNotFound: return "Invite not found"
        case .inviteExpired: return "This invite has expired"
        case .inviteUsedUp: return "This invite has already been used"
        case .alreadyMember: return "You're already a member of this circle"
        case .circleNotFound: return "Circle not found"
        case .rateLimitExceeded: return "Too many invites created. Please wait before creating more."
        case .invalidInviteData: return "Invalid invite data"
        case .profileNotFound: return "User profile not found"
        }
    }
}
