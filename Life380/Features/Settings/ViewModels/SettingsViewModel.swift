import Foundation
import Combine

/// ViewModel for settings
@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var userProfile: UserProfile?
    @Published var userSettings: UserSettings = .default

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
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(authService: AuthService, firestoreService: FirestoreService = .shared) {
        self.authService = authService
        self.firestoreService = firestoreService
    }

    // MARK: - Data Loading

    func loadUserProfile() async {
        guard let userId = authService.user?.uid else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            if let profile = try await firestoreService.fetchUserProfile(userId: userId) {
                userProfile = profile
                editDisplayName = profile.displayName
                editPhotoURL = profile.photoURL ?? ""
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Profile Updates

    func updateDisplayName() async -> Bool {
        guard let userId = authService.user?.uid else { return false }
        guard !editDisplayName.isEmpty else {
            errorMessage = "Display name cannot be empty"
            showError = true
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await firestoreService.updateUserProfile(
                userId: userId,
                updates: ["displayName": editDisplayName]
            )
            userProfile?.displayName = editDisplayName
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    // MARK: - Settings Updates

    func toggleLocationSharing() async {
        guard let userId = authService.user?.uid else { return }

        userSettings.isLocationSharingEnabled.toggle()

        do {
            try await firestoreService.updateUserProfile(
                userId: userId,
                updates: ["isLocationSharing": userSettings.isLocationSharingEnabled]
            )
        } catch {
            userSettings.isLocationSharingEnabled.toggle() // Revert on failure
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func updateLocationFrequency(_ frequency: LocationUpdateFrequency) async {
        guard let userId = authService.user?.uid else { return }

        let oldFrequency = userSettings.locationUpdateFrequency
        userSettings.locationUpdateFrequency = frequency

        do {
            try await firestoreService.updateUserSettings(
                userId: userId,
                settings: userSettings
            )
        } catch {
            userSettings.locationUpdateFrequency = oldFrequency // Revert on failure
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

    // MARK: - Data Export

    func exportUserData() async -> Data? {
        guard let userId = authService.user?.uid else { return nil }

        isLoading = true
        defer { isLoading = false }

        do {
            return try await firestoreService.exportUserData(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return nil
        }
    }

    // MARK: - Error Handling

    func clearError() {
        errorMessage = nil
        showError = false
    }
}
