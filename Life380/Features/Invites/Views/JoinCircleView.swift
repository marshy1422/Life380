import SwiftUI
import UIKit

struct JoinCircleView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @Environment(\.dismiss) private var dismiss

    /// Pre-filled code from deep link
    var prefilledCode: String?

    @State private var inviteCode = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var joinedCircle: FamilyCircle?
    @State private var showQRScanner = false
    @FocusState private var isCodeFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                // QR Scanner Section
                Section {
                    Button {
                        showQRScanner = true
                    } label: {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title2)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Scan QR Code")
                                    .foregroundColor(.primary)
                                Text("Point camera at invite QR code")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    TextField("Invite Code", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.title3, design: .monospaced))
                        .focused($isCodeFieldFocused)
                        .onChange(of: inviteCode) { _, newValue in
                            // Auto-uppercase and limit to 6 characters
                            let filtered = String(newValue.uppercased().prefix(6))
                            if filtered != newValue {
                                inviteCode = filtered
                            }
                        }
                } header: {
                    Text("Enter Invite Code")
                } footer: {
                    Text("Ask a circle member to share their invite code with you. It's a 6-character code.")
                }

                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                }

                if let circle = joinedCircle {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)
                                Text("Joined Successfully!")
                                    .font(.headline)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Circle Name")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(circle.name)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Members")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(circle.memberIds.count) member\(circle.memberIds.count == 1 ? "" : "s")")
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Section {
                        Button {
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Label("Done", systemImage: "checkmark")
                                Spacer()
                            }
                        }
                    }
                } else {
                    Section {
                        Button {
                            joinCircle()
                        } label: {
                            HStack {
                                Spacer()
                                if isJoining {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                }
                                Text(isJoining ? "Joining..." : "Join Circle")
                                Spacer()
                            }
                        }
                        .disabled(inviteCode.count != 6 || isJoining)
                    }
                }
            }
            .navigationTitle("Join Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Use prefilled code from deep link if provided
                if let code = prefilledCode, !code.isEmpty {
                    inviteCode = code.uppercased()
                    // Auto-join if code is prefilled
                    joinCircle()
                } else {
                    isCodeFieldFocused = true
                }
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerView { scannedCode in
                    inviteCode = scannedCode.uppercased()
                    // Auto-join after scanning
                    joinCircle()
                }
            }
        }
    }

    init(prefilledCode: String? = nil) {
        self.prefilledCode = prefilledCode
    }

    private func joinCircle() {
        let code = inviteCode.trimmingCharacters(in: .whitespaces).uppercased()
        guard code.count == 6 else { return }

        isJoining = true
        errorMessage = nil

        Task {
            do {
                let circle = try await firestoreService.joinCircle(inviteCode: code)
                joinedCircle = circle
            } catch {
                if let circleError = error as? FirestoreService.CircleError {
                    errorMessage = circleError.localizedDescription
                } else {
                    errorMessage = "Failed to join circle. Please check the code and try again."
                }
            }
            isJoining = false
        }
    }
}

#Preview {
    JoinCircleView(prefilledCode: nil)
        .environmentObject(FirestoreService.shared)
}
