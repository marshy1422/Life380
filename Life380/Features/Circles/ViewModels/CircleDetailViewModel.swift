import Foundation
import Combine

/// ViewModel for circle detail view
@MainActor
class CircleDetailViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var circle: FamilyCircle
    @Published var members: [UserProfile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    @Published var showRenameAlert = false
    @Published var newCircleName = ""

    // MARK: - Dependencies

    private let circleService: CircleService

    // MARK: - Initialization

    init(circle: FamilyCircle, circleService: CircleService? = nil) {
        self.circle = circle
        self.circleService = circleService ?? CircleService.shared
        self.newCircleName = circle.name
    }

    // MARK: - Data Loading

    func loadMembers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            members = try await circleService.fetchMembers(for: circle.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Circle Actions

    func renameCircle() async {
        guard !newCircleName.isEmpty else { return }

        do {
            try await circleService.renameCircle(circle.id, newName: newCircleName)
            circle.name = newCircleName
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Member Actions

    func removeMember(_ memberId: String, by userId: String) async {
        do {
            try await circleService.removeMember(memberId, from: circle.id, by: userId)
            await loadMembers()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Helpers

    func isAdmin(userId: String) -> Bool {
        circle.createdBy == userId
    }

    func canRemoveMember(_ memberId: String, currentUserId: String) -> Bool {
        isAdmin(userId: currentUserId) && memberId != currentUserId
    }

    func clearError() {
        errorMessage = nil
        showError = false
    }
}
