import Foundation
import FirebaseAuth

/// Firebase-specific authentication operations
/// Note: This is separate from AuthService which handles the full auth flow
enum FirebaseAuthService {

    // MARK: - Current User

    /// Returns the current Firebase user if signed in
    static var currentUser: User? {
        Auth.auth().currentUser
    }

    /// Returns the current user's ID if signed in
    static var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    /// Checks if a user is currently signed in
    static var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }

    // MARK: - Token Management

    /// Gets the current user's ID token for API authentication
    static func getIdToken(forceRefresh: Bool = false) async throws -> String {
        guard let user = currentUser else {
            throw FirebaseAuthError.notSignedIn
        }
        return try await user.getIDToken(forcingRefresh: forceRefresh)
    }

    // MARK: - Email Verification

    /// Sends a verification email to the current user
    static func sendEmailVerification() async throws {
        guard let user = currentUser else {
            throw FirebaseAuthError.notSignedIn
        }
        try await user.sendEmailVerification()
    }

    /// Checks if the current user's email is verified
    static var isEmailVerified: Bool {
        currentUser?.isEmailVerified ?? false
    }

    // MARK: - Profile Updates

    /// Updates the current user's display name
    static func updateDisplayName(_ name: String) async throws {
        guard let user = currentUser else {
            throw FirebaseAuthError.notSignedIn
        }

        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()
    }

    /// Updates the current user's photo URL
    static func updatePhotoURL(_ url: URL) async throws {
        guard let user = currentUser else {
            throw FirebaseAuthError.notSignedIn
        }

        let changeRequest = user.createProfileChangeRequest()
        changeRequest.photoURL = url
        try await changeRequest.commitChanges()
    }

    // MARK: - Password Management

    /// Updates the current user's password (requires recent authentication)
    static func updatePassword(_ newPassword: String) async throws {
        guard let user = currentUser else {
            throw FirebaseAuthError.notSignedIn
        }
        try await user.updatePassword(to: newPassword)
    }

    // MARK: - Email Updates

    /// Updates the current user's email (requires recent authentication)
    static func updateEmail(_ newEmail: String) async throws {
        guard let user = currentUser else {
            throw FirebaseAuthError.notSignedIn
        }
        try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)
    }

    // MARK: - Reload

    /// Reloads the current user's profile from the server
    static func reloadUser() async throws {
        guard let user = currentUser else {
            throw FirebaseAuthError.notSignedIn
        }
        try await user.reload()
    }
}

// MARK: - Errors

enum FirebaseAuthError: Error, LocalizedError {
    case notSignedIn
    case tokenRefreshFailed
    case emailUpdateFailed
    case passwordUpdateFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "No user is currently signed in"
        case .tokenRefreshFailed:
            return "Failed to refresh authentication token"
        case .emailUpdateFailed:
            return "Failed to update email address"
        case .passwordUpdateFailed:
            return "Failed to update password"
        }
    }
}
