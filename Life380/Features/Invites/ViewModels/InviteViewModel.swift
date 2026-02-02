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
    @Published var validatedCircle: FamilyCircle?
    @Published var validatedMemberCount: Int = 0

    // MARK: - Dependencies

    private let circleService: CircleService
    private let inviteService: InviteService

    // MARK: - Initialization

    init(circleService: CircleService? = nil, inviteService: InviteService? = nil) {
        self.circleService = circleService ?? CircleService.shared
        self.inviteService = inviteService ?? InviteService.shared
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

    func generateInvite(for circle: FamilyCircle) async {
        isLoading = true
        defer { isLoading = false }

        do {
            generatedInvite = try await inviteService.createInvite(for: circle)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Validate Invite

    func validateInviteCode(_ code: String) async -> Bool {
        let trimmedCode = code.trimmingCharacters(in: .whitespaces).uppercased()

        do {
            let result = try await inviteService.validateInviteCode(trimmedCode)
            validatedCircle = result.circle
            validatedMemberCount = result.memberCount
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
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
        validatedCircle = nil
        validatedMemberCount = 0
        clearError()
        clearSuccess()
    }
}
