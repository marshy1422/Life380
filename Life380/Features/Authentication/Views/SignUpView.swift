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

    // COPPA Age Verification
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var hasParentalConsent = false
    @State private var showingAgeBlockedAlert = false

    private var userAge: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }

    private var isUnder13: Bool {
        userAge < 13
    }

    private var isMinor: Bool {
        userAge < 18
    }

    var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    var isFormValid: Bool {
        let baseValid = !displayName.isEmpty && !email.isEmpty && password.count >= 6 && passwordsMatch && agreedToTerms
        let ageValid = !isUnder13 && (isMinor ? hasParentalConsent : true)
        return baseValid && ageValid
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

                // COPPA Age Verification Section
                Section {
                    DatePicker(
                        "Date of Birth",
                        selection: $dateOfBirth,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .onChange(of: dateOfBirth) { _, _ in
                        if isUnder13 {
                            showingAgeBlockedAlert = true
                        }
                    }

                    if isUnder13 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("You must be at least 13 years old to create an account.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else if isMinor {
                        Toggle(isOn: $hasParentalConsent) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("I have parental or guardian consent")
                                    .font(.subheadline)
                                Text("Required for users under 18")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Age Verification")
                } footer: {
                    Text("Life380 complies with COPPA regulations. Users under 13 cannot create accounts. Users 13-17 require parental consent.")
                        .font(.caption2)
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
            .alert("Age Requirement", isPresented: $showingAgeBlockedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Life380 requires users to be at least 13 years old to create an account. This is required by the Children's Online Privacy Protection Act (COPPA).")
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
