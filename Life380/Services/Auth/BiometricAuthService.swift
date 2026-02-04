import Foundation
import LocalAuthentication
import SwiftUI

/// Service for handling biometric (Face ID / Touch ID) authentication
@MainActor
class BiometricAuthService: ObservableObject {
    static let shared = BiometricAuthService()

    // Published state
    @Published var isAuthenticated: Bool = false
    @Published var biometricType: BiometricType = .none
    @Published var isAuthenticating: Bool = false
    @Published var authError: String?

    // Settings
    @AppStorage("requireBiometricOnLaunch") var requireOnLaunch: Bool = false
    @AppStorage("requireBiometricForLocationToggle") var requireForLocationToggle: Bool = true
    @AppStorage("requireBiometricForSOS") var requireForSOS: Bool = false

    // Security: Store lastAuthTime in Keychain instead of UserDefaults
    private static let lastAuthTimeKeychainKey = "com.life380.biometric.lastAuthTime"

    private var lastAuthTimeInterval: Double {
        get {
            guard let timeString = try? KeychainManager.getString(forKey: Self.lastAuthTimeKeychainKey),
                  let time = Double(timeString) else {
                return 0
            }
            return time
        }
        set {
            try? KeychainManager.save(String(newValue), forKey: Self.lastAuthTimeKeychainKey)
        }
    }

    // Configuration
    private let authValidityDuration: TimeInterval = 300 // 5 minutes

    private init() {
        checkBiometricAvailability()
    }

    // MARK: - Biometric Type Detection

    enum BiometricType: String {
        case none = "none"
        case touchID = "touchID"
        case faceID = "faceID"
        case opticID = "opticID"

        var displayName: String {
            switch self {
            case .none: return "Not Available"
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            case .opticID: return "Optic ID"
            }
        }

        var icon: String {
            switch self {
            case .none: return "lock.slash"
            case .touchID: return "touchid"
            case .faceID: return "faceid"
            case .opticID: return "opticid"
            }
        }
    }

    func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricType = .none
            return
        }

        switch context.biometryType {
        case .touchID:
            biometricType = .touchID
        case .faceID:
            biometricType = .faceID
        case .opticID:
            biometricType = .opticID
        case .none:
            biometricType = .none
        @unknown default:
            biometricType = .none
        }
    }

    var isBiometricAvailable: Bool {
        biometricType != .none
    }

    // MARK: - Authentication

    /// Authenticate with biometrics
    /// - Parameters:
    ///   - reason: The reason shown to the user
    ///   - fallbackTitle: Title for the fallback button (nil hides it)
    /// - Returns: Whether authentication succeeded
    func authenticate(reason: String, fallbackTitle: String? = "Use Passcode") async -> Bool {
        guard isBiometricAvailable else {
            authError = "Biometric authentication is not available"
            return false
        }

        // Check if still within validity period
        if isAuthenticationValid {
            return true
        }

        isAuthenticating = true
        authError = nil

        let context = LAContext()
        context.localizedFallbackTitle = fallbackTitle

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            isAuthenticating = false

            if success {
                isAuthenticated = true
                lastAuthTimeInterval = Date().timeIntervalSince1970
                return true
            } else {
                authError = "Authentication failed"
                return false
            }
        } catch let error as LAError {
            isAuthenticating = false
            handleAuthError(error)
            return false
        } catch {
            isAuthenticating = false
            authError = error.localizedDescription
            return false
        }
    }

    /// Authenticate with biometrics or passcode fallback
    func authenticateWithPasscodeFallback(reason: String) async -> Bool {
        let context = LAContext()

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication, // Allows passcode fallback
                localizedReason: reason
            )

            if success {
                isAuthenticated = true
                lastAuthTimeInterval = Date().timeIntervalSince1970
            }

            return success
        } catch {
            authError = error.localizedDescription
            return false
        }
    }

    private func handleAuthError(_ error: LAError) {
        switch error.code {
        case .authenticationFailed:
            authError = "Authentication failed. Please try again."
        case .userCancel:
            authError = nil // User cancelled, not an error
        case .userFallback:
            authError = nil // User chose passcode
        case .biometryNotAvailable:
            authError = "\(biometricType.displayName) is not available"
        case .biometryNotEnrolled:
            authError = "No \(biometricType.displayName) enrolled. Please set up in Settings."
        case .biometryLockout:
            authError = "\(biometricType.displayName) is locked. Use passcode to unlock."
        case .passcodeNotSet:
            authError = "Please set up a passcode in Settings"
        default:
            authError = error.localizedDescription
        }
    }

    // MARK: - Auth Validity

    var isAuthenticationValid: Bool {
        guard isAuthenticated else { return false }
        let lastAuth = Date(timeIntervalSince1970: lastAuthTimeInterval)
        return Date().timeIntervalSince(lastAuth) < authValidityDuration
    }

    func invalidateAuthentication() {
        isAuthenticated = false
        lastAuthTimeInterval = 0
    }

    // MARK: - Protected Actions

    /// Require authentication before performing an action
    func requireAuth(
        for action: String,
        perform: @escaping () async -> Void
    ) async {
        let reason = "Authenticate to \(action)"

        if await authenticate(reason: reason) {
            await perform()
        }
    }

    /// Check if authentication is required for a specific action
    func isAuthRequired(for action: ProtectedAction) -> Bool {
        switch action {
        case .appLaunch:
            return requireOnLaunch
        case .toggleLocationSharing:
            return requireForLocationToggle
        case .triggerSOS:
            return requireForSOS
        case .viewSensitiveData:
            return true // Always require
        case .deleteAccount:
            return true // Always require
        }
    }

    enum ProtectedAction {
        case appLaunch
        case toggleLocationSharing
        case triggerSOS
        case viewSensitiveData
        case deleteAccount
    }
}

// MARK: - SwiftUI View Modifier

struct BiometricProtectedModifier: ViewModifier {
    @StateObject private var authService = BiometricAuthService.shared
    let action: BiometricAuthService.ProtectedAction
    let onAuthenticated: () -> Void
    @State private var showingAuth = false

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if authService.isAuthRequired(for: action) && !authService.isAuthenticationValid {
                    showingAuth = true
                    Task {
                        let success = await authService.authenticate(
                            reason: "Authenticate to continue"
                        )
                        if success {
                            onAuthenticated()
                        }
                        showingAuth = false
                    }
                } else {
                    onAuthenticated()
                }
            }
            .overlay {
                if showingAuth {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                }
            }
    }
}

extension View {
    func biometricProtected(
        for action: BiometricAuthService.ProtectedAction,
        onAuthenticated: @escaping () -> Void
    ) -> some View {
        modifier(BiometricProtectedModifier(action: action, onAuthenticated: onAuthenticated))
    }
}

// MARK: - Biometric Settings View

struct BiometricSettingsView: View {
    @StateObject private var authService = BiometricAuthService.shared

    var body: some View {
        Section {
            if authService.isBiometricAvailable {
                HStack {
                    Image(systemName: authService.biometricType.icon)
                        .foregroundColor(.blue)
                    Text(authService.biometricType.displayName)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }

                Toggle("Require on App Launch", isOn: $authService.requireOnLaunch)

                Toggle("Require to Toggle Location", isOn: $authService.requireForLocationToggle)

                Toggle("Require for SOS", isOn: $authService.requireForSOS)

            } else {
                HStack {
                    Image(systemName: "lock.slash")
                        .foregroundColor(.gray)
                    Text("Biometrics Not Available")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Biometric Security")
        } footer: {
            if authService.isBiometricAvailable {
                Text("Use \(authService.biometricType.displayName) to protect sensitive actions")
            } else {
                Text("Set up Face ID or Touch ID in device Settings to enable")
            }
        }
    }
}

#Preview {
    Form {
        BiometricSettingsView()
    }
}
