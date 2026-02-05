import Foundation
import CoreLocation
import AuthenticationServices

/// ViewModel for authentication views
@MainActor
class AuthViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var displayName = ""

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    @Published var isEmailValid = false
    @Published var isPasswordValid = false
    @Published var passwordsMatch = false

    // MARK: - Dependencies

    private let authService: AuthService
    private let locationManager: PrecisionLocationManager?

    // MARK: - Initialization

    init(authService: AuthService, locationManager: PrecisionLocationManager? = nil) {
        self.authService = authService
        self.locationManager = locationManager
    }

    // MARK: - Validation

    func validateEmail() {
        isEmailValid = email.isValidEmail
    }

    func validatePassword() {
        isPasswordValid = password.count >= 8
    }

    func validatePasswordMatch() {
        passwordsMatch = password == confirmPassword && !password.isEmpty
    }

    var canSignIn: Bool {
        isEmailValid && isPasswordValid
    }

    var canSignUp: Bool {
        isEmailValid && isPasswordValid && passwordsMatch && !displayName.isEmpty
    }

    // MARK: - Actions

    func signIn() async {
        guard canSignIn else {
            errorMessage = "Please enter valid email and password"
            showError = true
            return
        }

        isLoading = true
        await authService.signIn(email: email, password: password)
        isLoading = false

        if let error = authService.errorMessage {
            errorMessage = error
            showError = true
        }
    }

    func signUp() async {
        guard canSignUp else {
            errorMessage = "Please fill in all fields correctly"
            showError = true
            return
        }

        isLoading = true

        let location = locationManager?.currentLocation?.coordinate
        let accuracy = locationManager?.currentLocation?.horizontalAccuracy

        await authService.signUp(
            email: email,
            password: password,
            displayName: displayName,
            location: location,
            accuracy: accuracy
        )

        isLoading = false

        if let error = authService.errorMessage {
            errorMessage = error
            showError = true
        }
    }

    func resetPassword() async {
        guard isEmailValid else {
            errorMessage = "Please enter a valid email address"
            showError = true
            return
        }

        isLoading = true
        await authService.resetPassword(email: email)
        isLoading = false

        if let error = authService.errorMessage {
            errorMessage = error
            showError = true
        }
    }

    func signOut() {
        authService.signOut()
    }

    // MARK: - Apple Sign In

    func prepareAppleSignIn() -> String? {
        authService.prepareSignInWithApple()
    }

    func handleAppleSignIn(authorization: ASAuthorization) async {
        isLoading = true

        let location = locationManager?.currentLocation?.coordinate
        let accuracy = locationManager?.currentLocation?.horizontalAccuracy

        await authService.handleSignInWithApple(
            authorization: authorization,
            location: location,
            accuracy: accuracy
        )

        isLoading = false

        if let error = authService.errorMessage {
            errorMessage = error
            showError = true
        }
    }

    // MARK: - Error Handling

    func clearError() {
        errorMessage = nil
        showError = false
    }

    func clearFields() {
        email = ""
        password = ""
        confirmPassword = ""
        displayName = ""
        clearError()
    }
}
