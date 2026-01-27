import SwiftUI
import AuthenticationServices

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthenticationService

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agreedToTerms = false

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
                        if authService.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
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
                    .disabled(!isFormValid || authService.isLoading)
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
                                await authService.handleSignInWithApple(authorization: authorization)
                                if authService.isAuthenticated {
                                    dismiss()
                                }
                            }
                        case .failure(let error):
                            authService.errorMessage = error.localizedDescription
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
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
            await authService.signUp(email: email, password: password, displayName: displayName)
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthenticationService())
}
