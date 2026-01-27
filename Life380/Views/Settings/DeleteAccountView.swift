import SwiftUI
import FirebaseAuth

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthenticationService

    @State private var email = ""
    @State private var password = ""
    @State private var confirmText = ""
    @State private var showingConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private let confirmationPhrase = "DELETE"

    var canDelete: Bool {
        confirmText == confirmationPhrase && !email.isEmpty && !password.isEmpty
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)

                    Text("Delete Your Account")
                        .font(.title2.bold())

                    Text("This action is permanent and cannot be undone.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What will be deleted:")
                        .font(.headline)

                    deleteItem("Your profile and account information")
                    deleteItem("All your location history")
                    deleteItem("Your places and saved locations")
                    deleteItem("Your membership in all circles")
                }
                .padding(.vertical, 8)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What will NOT be deleted:")
                        .font(.headline)

                    retainItem("Messages you've sent to circle members")
                    retainItem("Data required by law to be retained")
                }
                .padding(.vertical, 8)
            }

            Section("Re-authenticate to Continue") {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)

                SecureField("Password", text: $password)
                    .textContentType(.password)
            }

            Section("Confirm Deletion") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Type \"\(confirmationPhrase)\" to confirm:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("Type \(confirmationPhrase)", text: $confirmText)
                        .textInputAutocapitalization(.characters)
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button(role: .destructive, action: { showingConfirmation = true }) {
                    if isDeleting {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                            Text("Permanently Delete Account")
                            Spacer()
                        }
                    }
                }
                .disabled(!canDelete || isDeleting)
            }
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Are you absolutely sure?", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Forever", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
        }
    }

    private func deleteItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
            Text(text)
                .font(.subheadline)
        }
    }

    private func retainItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
            Text(text)
                .font(.subheadline)
        }
    }

    private func deleteAccount() {
        isDeleting = true
        errorMessage = nil

        Task {
            // Re-authenticate first
            let reauthSuccess = await authService.reauthenticate(email: email, password: password)

            if !reauthSuccess {
                errorMessage = authService.errorMessage ?? "Failed to verify credentials"
                isDeleting = false
                return
            }

            // Delete account
            let deleteSuccess = await authService.deleteAccount()

            if deleteSuccess {
                dismiss()
            } else {
                errorMessage = authService.errorMessage ?? "Failed to delete account"
            }

            isDeleting = false
        }
    }
}

#Preview {
    NavigationStack {
        DeleteAccountView()
            .environmentObject(AuthenticationService())
    }
}
