import SwiftUI
import MessageUI

struct BetaFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackType: FeedbackType = .bug
    @State private var description: String = ""
    @State private var includeDeviceInfo: Bool = true
    @State private var showingMailComposer: Bool = false
    @State private var showingCopiedAlert: Bool = false
    @State private var isSending: Bool = false

    enum FeedbackType: String, CaseIterable {
        case bug = "Bug Report"
        case feature = "Feature Request"
        case general = "General Feedback"

        var icon: String {
            switch self {
            case .bug: return "ladybug.fill"
            case .feature: return "lightbulb.fill"
            case .general: return "bubble.left.fill"
            }
        }

        var color: Color {
            switch self {
            case .bug: return .red
            case .feature: return .orange
            case .general: return .blue
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Feedback Type
                Section("Feedback Type") {
                    Picker("Type", selection: $feedbackType) {
                        ForEach(FeedbackType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Description
                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 150)

                    if feedbackType == .bug {
                        Text("Please describe what happened, what you expected, and steps to reproduce the issue.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Device Info
                Section {
                    Toggle("Include Device Information", isOn: $includeDeviceInfo)

                    if includeDeviceInfo {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Will include:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("• App version: \(appVersion)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("• iOS version: \(iosVersion)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("• Device: \(deviceModel)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Text("Device info helps us diagnose issues faster.")
                }

                // Send Options
                Section {
                    Button(action: sendViaEmail) {
                        Label("Send via Email", systemImage: "envelope.fill")
                    }
                    .disabled(description.isEmpty)

                    Button(action: copyToClipboard) {
                        Label("Copy to Clipboard", systemImage: "doc.on.doc.fill")
                    }
                    .disabled(description.isEmpty)
                }
            }
            .navigationTitle("Beta Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Copied!", isPresented: $showingCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Feedback copied to clipboard. You can paste it in an email or message.")
            }
            .sheet(isPresented: $showingMailComposer) {
                MailComposerView(
                    subject: "[\(feedbackType.rawValue)] Life380 Beta Feedback",
                    body: composedFeedback,
                    recipients: ["feedback@life380.app"]
                )
            }
        }
    }

    // MARK: - Computed Properties

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private var iosVersion: String {
        UIDevice.current.systemVersion
    }

    private var deviceModel: String {
        UIDevice.current.model
    }

    private var composedFeedback: String {
        var feedback = """
        Type: \(feedbackType.rawValue)

        Description:
        \(description)
        """

        if includeDeviceInfo {
            feedback += """


            ---
            Device Information:
            • App Version: \(appVersion)
            • iOS Version: \(iosVersion)
            • Device: \(deviceModel)
            • Date: \(Date().formatted())
            """
        }

        return feedback
    }

    // MARK: - Actions

    private func sendViaEmail() {
        if MFMailComposeViewController.canSendMail() {
            showingMailComposer = true
        } else {
            // Fallback - copy to clipboard
            copyToClipboard()
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = composedFeedback
        showingCopiedAlert = true
    }
}

// MARK: - Mail Composer

struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let recipients: [String]

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        composer.setToRecipients(recipients)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - App Info View

struct AppInfoView: View {
    var body: some View {
        VStack(spacing: 16) {
            // App Icon
            Image(systemName: "location.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)

            // App Name & Version
            VStack(spacing: 4) {
                Text("Life380")
                    .font(.title2.bold())

                Text("Version \(appVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Beta")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .cornerRadius(4)
            }

            Divider()
                .padding(.horizontal, 40)

            // Build Info
            VStack(spacing: 8) {
                AppInfoRow(label: "Build", value: buildNumber)
                AppInfoRow(label: "iOS", value: UIDevice.current.systemVersion)
                AppInfoRow(label: "Device", value: UIDevice.current.model)
            }
            .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

struct AppInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.horizontal)
    }
}

#Preview {
    BetaFeedbackView()
}
