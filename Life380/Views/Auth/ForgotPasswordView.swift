import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthenticationService

    @State private var email = ""
    @State private var emailSent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if emailSent {
                    // Success State
                    VStack(spacing: 16) {
                        Image(systemName: "envelope.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("Check Your Email")
                            .font(.title2.bold())

                        Text("We've sent password reset instructions to \(email)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                } else {
                    // Form State
                    VStack(spacing: 16) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Reset Password")
                            .font(.title2.bold())

                        Text("Enter your email address and we'll send you instructions to reset your password.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        TextField("Email", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .padding(.horizontal, 32)
                            .padding(.top)

                        if let error = authService.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        Button(action: resetPassword) {
                            if authService.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Send Reset Link")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(email.isEmpty || authService.isLoading)
                        .padding(.horizontal, 32)
                    }
                }

                Spacer()
            }
            .padding(.top, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func resetPassword() {
        Task {
            await authService.resetPassword(email: email)
            if authService.errorMessage == nil {
                emailSent = true
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(AuthenticationService())
}
