import Foundation
import Combine

/// ViewModel for settings
@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var isLocationSharingEnabled = true

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Sheet States

    @Published var showEditProfile = false
    @Published var showPrivacySettings = false
    @Published var showNotificationSettings = false
    @Published var showLocationSettings = false
    @Published var showDeleteAccount = false
    @Published var showDataExport = false
    @Published var showBetaFeedback = false

    // MARK: - Edit Profile Form

    @Published var editDisplayName = ""
    @Published var editPhotoURL = ""

    // MARK: - Dependencies

    private let authService: AuthService
    private let firestoreService: FirestoreService

    // MARK: - Initialization

    init(authService: AuthService, firestoreService: FirestoreService = .shared) {
        self.authService = authService
        self.firestoreService = firestoreService
    }

    // MARK: - Profile Updates

    func updateDisplayName() async -> Bool {
        guard !editDisplayName.isEmpty else {
            errorMessage = "Display name cannot be empty"
            showError = true
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await firestoreService.updateUserProfile(displayName: editDisplayName)
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    // MARK: - Settings Updates

    func toggleLocationSharing() async {
        let newValue = !isLocationSharingEnabled
        isLocationSharingEnabled = newValue

        do {
            try await firestoreService.updateUserProfile(isLocationSharing: newValue)
        } catch {
            isLocationSharingEnabled = !newValue // Revert on failure
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Account Actions

    func signOut() {
        authService.signOut()
    }

    func deleteAccount() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        return await authService.deleteAccount()
    }

    // MARK: - Error Handling

    func clearError() {
        errorMessage = nil
        showError = false
    }
}
