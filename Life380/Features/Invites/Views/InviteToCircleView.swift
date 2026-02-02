import SwiftUI
import UIKit

struct InviteToCircleView: View {
    @Environment(\.dismiss) private var dismiss
    let circle: FamilyCircle

    @State private var qrCodeImage: UIImage?
    @State private var showShareSheet = false
    @State private var copiedToClipboard = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 50))
                            .foregroundStyle(.blue)

                        Text("Invite to \(circle.name)")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Share this code with family members")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // QR Code
                    VStack(spacing: 16) {
                        if let qrImage = qrCodeImage {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                                .padding(20)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        } else {
                            ProgressView()
                                .frame(width: 200, height: 200)
                        }

                        Text("Scan with Life380 app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Invite Code Display
                    VStack(spacing: 12) {
                        Text("Or use this code:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 16) {
                            Text(circle.inviteCode)
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .tracking(4)

                            Button {
                                copyToClipboard()
                            } label: {
                                Image(systemName: copiedToClipboard ? "checkmark.circle.fill" : "doc.on.doc")
                                    .font(.title2)
                                    .foregroundColor(copiedToClipboard ? .green : .blue)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        if copiedToClipboard {
                            Text("Copied!")
                                .font(.caption)
                                .foregroundColor(.green)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut, value: copiedToClipboard)

                    Divider()
                        .padding(.horizontal)

                    // Share Options
                    VStack(spacing: 16) {
                        Button {
                            showShareSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Invite")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        Button {
                            shareViaMessages()
                        } label: {
                            HStack {
                                Image(systemName: "message.fill")
                                Text("Send via Messages")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                generateQRCode()
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: InviteService.shared.shareItems(for: circle))
            }
        }
    }

    private func generateQRCode() {
        qrCodeImage = circle.generateQRCode(size: 200)
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = circle.inviteCode
        copiedToClipboard = true

        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedToClipboard = false
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func shareViaMessages() {
        guard let url = URL(string: "sms:&body=\(circle.shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            return
        }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    InviteToCircleView(circle: FamilyCircle(
        id: "test",
        name: "Smith Family",
        createdBy: "user1",
        memberIds: ["user1"],
        inviteCode: "ABC123",
        createdAt: Date()
    ))
}
