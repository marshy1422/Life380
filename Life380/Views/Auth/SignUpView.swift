import SwiftUI
import AuthenticationServices
import CoreLocation

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var locationManager: PrecisionLocationManager

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agreedToTerms = false
    @State private var isRequestingLocation = false

    var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    var isFormValid: Bool {
        !displayName.isEmpty && !email.isEmpty && password.count >= 6 && passwordsMatch && agreedToTerms
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display Name", text: $displayName)
                        .textContentType(.name)

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                }

                Section {
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)

                    if !password.isEmpty && password.count < 6 {
                        Text("Password must be at least 6 characters")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    if !confirmPassword.isEmpty && !passwordsMatch {
                        Text("Passwords don't match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                // Terms and Privacy (Required by App Store)
                Section {
                    Toggle(isOn: $agreedToTerms) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("I agree to the Terms of Service and Privacy Policy")
                                .font(.subheadline)
                        }
                    }

                    NavigationLink("Terms of Service") {
                        TermsOfServiceView()
                    }
                    .font(.footnote)

                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }
                    .font(.footnote)
                }

                if let error = authService.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: signUp) {
                        if authService.isLoading || isRequestingLocation {
                            HStack {
                                Spacer()
                                ProgressView()
                                Text(isRequestingLocation ? "Getting location..." : "Creating account...")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Create Account")
                                Spacer()
                            }
                        }
                    }
                    .disabled(!isFormValid || authService.isLoading || isRequestingLocation)
                }

                // Sign in with Apple option
                Section {
                    SignInWithAppleButton(.signUp) { request in
                        let nonce = authService.prepareSignInWithApple()
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = nonce
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            Task {
                                // Get location before creating profile (fixes "Null Island" bug)
                                locationManager.requestPermission()
                                locationManager.startTracking()
                                let location = await waitForLocation(timeout: 3.0)

                                await authService.handleSignInWithApple(
                                    authorization: authorization,
                                    location: location?.coordinate,
                                    accuracy: location?.horizontalAccuracy
                                )
                                if authService.isAuthenticated {
                                    dismiss()
                                }
                            }
                        case .failure(let error):
                            authService.errorMessage = error.localizedDescription
                        }
                    }
                    .signInWithAppleButtonStyle(.adaptive(for: colorScheme))
                    .frame(height: 50)
                } header: {
                    Text("Or sign up with")
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    dismiss()
                }
            }
        }
    }

    private func signUp() {
        Task {
            // Request location permission and get initial location before creating profile
            // This fixes the "Null Island" bug where users appear at (0,0) after sign-up
            isRequestingLocation = true
            locationManager.requestPermission()
            locationManager.startTracking()

            // Wait briefly for location (with timeout to not block sign-up)
            let location = await waitForLocation(timeout: 3.0)
            isRequestingLocation = false

            await authService.signUp(
                email: email,
                password: password,
                displayName: displayName,
                location: location?.coordinate,
                accuracy: location?.horizontalAccuracy
            )
        }
    }

    /// Wait for location with timeout - returns nil if location not available in time
    private func waitForLocation(timeout: TimeInterval) async -> PrecisionLocation? {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if let location = locationManager.currentLocation,
               location.horizontalAccuracy < 100 {  // Only accept reasonably accurate locations
                return location
            }
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        }

        // Return current location even if not ideal (better than nil in most cases)
        return locationManager.currentLocation
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthenticationService())
        .environmentObject(PrecisionLocationManager())
}
