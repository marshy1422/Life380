import Foundation

/// ViewModel for invite-related views
@MainActor
class InviteViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var inviteCode = ""
    @Published var circleName = ""

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showSuccess = false
    @Published var successMessage = ""

    @Published var generatedInvite: CircleInvite?

    // MARK: - Dependencies

    private let circleService: CircleService
    private let inviteService: InviteService

    // MARK: - Initialization

    init(circleService: CircleService = .shared, inviteService: InviteService = .shared) {
        self.circleService = circleService
        self.inviteService = inviteService
    }

    // MARK: - Create Circle

    func createCircle(name: String, userId: String) async -> Bool {
        guard !name.isEmpty else {
            errorMessage = "Please enter a circle name"
            showError = true
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let circle = try await circleService.createCircle(name: name, createdBy: userId)
            successMessage = "Circle '\(circle.name)' created successfully!"
            showSuccess = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    // MARK: - Join Circle

    func joinCircle(code: String, userId: String) async -> Bool {
        let trimmedCode = code.trimmingCharacters(in: .whitespaces).uppercased()

        guard trimmedCode.count == 6 else {
            errorMessage = "Please enter a valid 6-character invite code"
            showError = true
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await circleService.joinCircle(inviteCode: trimmedCode, userId: userId)
            successMessage = "Successfully joined the circle!"
            showSuccess = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    // MARK: - Generate Invite

    func generateInvite(for circle: FamilyCircle, by userId: String, userName: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            generatedInvite = try await inviteService.createInvite(for: circle, by: userId, userName: userName)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Validate Invite

    func validateInviteCode(_ code: String) async -> CircleInvite? {
        let trimmedCode = code.trimmingCharacters(in: .whitespaces).uppercased()

        do {
            return try await inviteService.validateInviteCode(trimmedCode)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return nil
        }
    }

    // MARK: - Helpers

    func clearError() {
        errorMessage = nil
        showError = false
    }

    func clearSuccess() {
        successMessage = ""
        showSuccess = false
    }

    func reset() {
        inviteCode = ""
        circleName = ""
        generatedInvite = nil
        clearError()
        clearSuccess()
    }
}
