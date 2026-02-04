import Foundation
import FirebaseFirestore
import Combine

/// Service for managing circles and their members
@MainActor
class CircleService: ObservableObject {
    static let shared = CircleService()

    @Published var circles: [FamilyCircle] = []
    @Published var selectedCircle: FamilyCircle?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var circleListeners: [ListenerRegistration] = []

    private init() {}

    // MARK: - Circle CRUD

    /// Creates a new circle
    func createCircle(name: String, createdBy userId: String) async throws -> FamilyCircle {
        isLoading = true
        defer { isLoading = false }

        let inviteCode = generateInviteCode()
        let circleId = UUID().uuidString

        let circle = FamilyCircle(
            id: circleId,
            name: name,
            createdBy: userId,
            memberIds: [userId],
            inviteCode: inviteCode,
            createdAt: Date()
        )

        try await db.collection("circles").document(circleId).setData(circle.dictionary)

        // Add circle to user's circleIds
        try await db.collection("users").document(userId).updateData([
            "circleIds": FieldValue.arrayUnion([circleId])
        ])

        circles.append(circle)
        return circle
    }

    /// Fetches all circles for a user
    func fetchCircles(for userId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let snapshot = try await db.collection("circles")
            .whereField("memberIds", arrayContains: userId)
            .getDocuments()

        circles = snapshot.documents.compactMap { FamilyCircle(dictionary: $0.data()) }

        if selectedCircle == nil, let first = circles.first {
            selectedCircle = first
        }
    }

    /// Listens for real-time updates to user's circles
    func listenToCircles(for userId: String) {
        let listener = db.collection("circles")
            .whereField("memberIds", arrayContains: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let documents = snapshot?.documents else { return }

                Task { @MainActor in
                    self.circles = documents.compactMap { FamilyCircle(dictionary: $0.data()) }

                    // Update selected circle if it still exists
                    if let selected = self.selectedCircle {
                        self.selectedCircle = self.circles.first { $0.id == selected.id }
                    }
                }
            }

        circleListeners.append(listener)
    }

    /// Deletes a circle (only creator can delete)
    func deleteCircle(_ circleId: String, by userId: String) async throws {
        guard let circle = circles.first(where: { $0.id == circleId }) else {
            throw CircleError.circleNotFound
        }

        guard circle.createdBy == userId else {
            throw CircleError.notAuthorized
        }

        // Remove circle from all members' circleIds
        for memberId in circle.memberIds {
            try await db.collection("users").document(memberId).updateData([
                "circleIds": FieldValue.arrayRemove([circleId])
            ])
        }

        // Delete the circle
        try await db.collection("circles").document(circleId).delete()

        circles.removeAll { $0.id == circleId }

        if selectedCircle?.id == circleId {
            selectedCircle = circles.first
        }
    }

    /// Renames a circle
    func renameCircle(_ circleId: String, newName: String) async throws {
        try await db.collection("circles").document(circleId).updateData([
            "name": newName
        ])

        if let index = circles.firstIndex(where: { $0.id == circleId }) {
            circles[index].name = newName
        }
    }

    // MARK: - Membership

    /// Joins a circle using an invite code
    func joinCircle(inviteCode: String, userId: String) async throws {
        isLoading = true
        defer { isLoading = false }

        // Find circle with matching invite code
        let snapshot = try await db.collection("circles")
            .whereField("inviteCode", isEqualTo: inviteCode.uppercased())
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first,
              var circle = FamilyCircle(dictionary: document.data()) else {
            throw CircleError.invalidInviteCode
        }

        // Check if already a member
        if circle.memberIds.contains(userId) {
            throw CircleError.alreadyMember
        }

        // Add user to circle
        circle.memberIds.append(userId)
        try await db.collection("circles").document(circle.id).updateData([
            "memberIds": FieldValue.arrayUnion([userId])
        ])

        // Add circle to user's circleIds
        try await db.collection("users").document(userId).updateData([
            "circleIds": FieldValue.arrayUnion([circle.id])
        ])

        circles.append(circle)
    }

    /// Leaves a circle
    func leaveCircle(_ circleId: String, userId: String) async throws {
        guard let circle = circles.first(where: { $0.id == circleId }) else {
            throw CircleError.circleNotFound
        }

        // Creator cannot leave - they must delete the circle
        if circle.createdBy == userId {
            throw CircleError.creatorCannotLeave
        }

        // Remove user from circle
        try await db.collection("circles").document(circleId).updateData([
            "memberIds": FieldValue.arrayRemove([userId])
        ])

        // Remove circle from user's circleIds
        try await db.collection("users").document(userId).updateData([
            "circleIds": FieldValue.arrayRemove([circleId])
        ])

        circles.removeAll { $0.id == circleId }

        if selectedCircle?.id == circleId {
            selectedCircle = circles.first
        }
    }

    /// Removes a member from a circle (only creator can do this)
    func removeMember(_ memberId: String, from circleId: String, by userId: String) async throws {
        guard let circle = circles.first(where: { $0.id == circleId }) else {
            throw CircleError.circleNotFound
        }

        guard circle.createdBy == userId else {
            throw CircleError.notAuthorized
        }

        // Cannot remove the creator
        if memberId == circle.createdBy {
            throw CircleError.cannotRemoveCreator
        }

        // Remove member from circle
        try await db.collection("circles").document(circleId).updateData([
            "memberIds": FieldValue.arrayRemove([memberId])
        ])

        // Remove circle from member's circleIds
        try await db.collection("users").document(memberId).updateData([
            "circleIds": FieldValue.arrayRemove([circleId])
        ])
    }

    // MARK: - Members

    /// Fetches all members of a circle
    func fetchMembers(for circleId: String) async throws -> [UserProfile] {
        guard let circle = circles.first(where: { $0.id == circleId }) else {
            throw CircleError.circleNotFound
        }

        var members: [UserProfile] = []

        for memberId in circle.memberIds {
            let document = try await db.collection("users").document(memberId).getDocument()
            if let profile = UserProfile(dictionary: document.data() ?? [:]) {
                members.append(profile)
            }
        }

        return members
    }

    // MARK: - Helpers

    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Excludes confusing characters
        guard !characters.isEmpty else {
            return "000000" // Fallback code - should never happen
        }
        return String((0..<6).compactMap { _ in characters.randomElement() })
    }

    func stopListening() {
        circleListeners.forEach { $0.remove() }
        circleListeners.removeAll()
    }
}

// MARK: - Errors

enum CircleError: Error, LocalizedError {
    case circleNotFound
    case invalidInviteCode
    case alreadyMember
    case notAuthorized
    case creatorCannotLeave
    case cannotRemoveCreator

    var errorDescription: String? {
        switch self {
        case .circleNotFound:
            return "Circle not found"
        case .invalidInviteCode:
            return "Invalid invite code"
        case .alreadyMember:
            return "You're already a member of this circle"
        case .notAuthorized:
            return "You're not authorized to perform this action"
        case .creatorCannotLeave:
            return "Circle creator cannot leave. Delete the circle instead."
        case .cannotRemoveCreator:
            return "Cannot remove the circle creator"
        }
    }
}
