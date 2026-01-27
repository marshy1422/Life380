import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit
import Combine

@MainActor
class AuthenticationService: NSObject, ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var authStateHandler: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    override init() {
        super.init()
        setupAuthStateListener()
    }

    private func setupAuthStateListener() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isAuthenticated = user != nil
        }
    }

    // MARK: - Email Authentication

    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)

            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()

            try await FirestoreService.shared.createUserProfile(
                userId: result.user.uid,
                email: email,
                displayName: displayName
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Sign in with Apple (Required by App Store)

    func handleSignInWithApple(authorization: ASAuthorization) async {
        isLoading = true
        errorMessage = nil

        // Clear nonce after use for security
        defer { currentNonce = nil }

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            errorMessage = "Unable to fetch identity token"
            isLoading = false
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        do {
            let result = try await Auth.auth().signIn(with: credential)

            // Create profile if new user
            let displayName = [
                appleIDCredential.fullName?.givenName,
                appleIDCredential.fullName?.familyName
            ].compactMap { $0 }.joined(separator: " ")

            let email = appleIDCredential.email ?? result.user.email ?? ""

            // Check if user profile exists
            let profileExists = try await FirestoreService.shared.userProfileExists(userId: result.user.uid)
            if !profileExists {
                try await FirestoreService.shared.createUserProfile(
                    userId: result.user.uid,
                    email: email,
                    displayName: displayName.isEmpty ? "User" : displayName
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func prepareSignInWithApple() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    // MARK: - Account Deletion (Required by App Store)

    func deleteAccount() async -> Bool {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user signed in"
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            // Delete user data from Firestore first
            try await FirestoreService.shared.deleteUserData(userId: user.uid)

            // Delete Firebase Auth account
            try await user.delete()

            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Re-authentication (needed before sensitive operations)

    func reauthenticate(email: String, password: String) async -> Bool {
        guard let user = Auth.auth().currentUser else { return false }

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        do {
            try await user.reauthenticate(with: credential)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)

        // Fallback to UUID-based generation if secure random fails (avoid crashing in production)
        if errorCode != errSecSuccess {
            #if DEBUG
            print("SecRandomCopyBytes failed with OSStatus \(errorCode), using fallback")
            #endif
            // Use multiple UUIDs to reach desired length
            var fallbackNonce = ""
            while fallbackNonce.count < length {
                fallbackNonce += UUID().uuidString.replacingOccurrences(of: "-", with: "")
            }
            return String(fallbackNonce.prefix(length))
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }

    deinit {
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task {
            await handleSignInWithApple(authorization: authorization)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        errorMessage = error.localizedDescription
    }
}
