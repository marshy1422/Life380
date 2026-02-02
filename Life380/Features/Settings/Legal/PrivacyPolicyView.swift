import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title.bold())
                    .padding(.bottom, 8)

                Text("Last updated: \(formattedDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Group {
                    sectionTitle("1. Information We Collect")

                    subSectionTitle("Personal Information")
                    sectionText("""
                    • Email address
                    • Display name
                    • Profile photo (optional)
                    """)

                    subSectionTitle("Location Data")
                    sectionText("""
                    • Real-time GPS location
                    • Location history within your circles
                    • Places you create (home, work, etc.)
                    """)

                    subSectionTitle("Device Information")
                    sectionText("""
                    • Device type and model
                    • Operating system version
                    • Battery level (when shared)
                    • Unique device identifiers
                    """)

                    subSectionTitle("Usage Data")
                    sectionText("""
                    • App interactions
                    • Feature usage
                    • Crash reports
                    """)
                }

                Group {
                    sectionTitle("2. How We Use Your Information")
                    sectionText("""
                    • To provide location sharing services
                    • To send arrival/departure notifications
                    • To improve our services
                    • To communicate with you about the App
                    • To ensure the security of our platform
                    """)

                    sectionTitle("3. Information Sharing")
                    sectionText("""
                    We share your information only in these circumstances:
                    • With your circle members (location, battery level)
                    • With service providers who assist our operations
                    • When required by law
                    • With your explicit consent

                    We do NOT sell your personal information to third parties.
                    """)

                    sectionTitle("4. Data Security")
                    sectionText("""
                    We implement industry-standard security measures including:
                    • Encryption in transit and at rest
                    • Secure authentication
                    • Regular security audits
                    • Access controls
                    """)
                }

                Group {
                    sectionTitle("5. Your Rights and Choices")
                    sectionText("""
                    You have the right to:
                    • Access your personal data
                    • Correct inaccurate data
                    • Delete your account and data
                    • Disable location sharing
                    • Opt out of notifications
                    • Export your data
                    """)

                    sectionTitle("6. Data Retention")
                    sectionText("""
                    • Location history: Retained for 7 days
                    • Account data: Retained until you delete your account
                    • After account deletion: Data removed within 30 days
                    """)

                    sectionTitle("7. Children's Privacy")
                    sectionText("""
                    Life380 is designed for family use. Users under 13 must have parental consent. We comply with COPPA (Children's Online Privacy Protection Act) requirements.
                    """)

                    sectionTitle("8. California Privacy Rights")
                    sectionText("""
                    California residents have additional rights under CCPA, including the right to know what data we collect and the right to request deletion.
                    """)

                    sectionTitle("9. International Users")
                    sectionText("""
                    If you are located outside the United States, your data may be transferred to and processed in the United States. We comply with applicable data protection laws including GDPR for EU users.
                    """)

                    sectionTitle("10. Contact Us")
                    sectionText("""
                    For privacy-related inquiries:
                    Email: privacy@life380.com
                    """)
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: Date())
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .padding(.top, 8)
    }

    private func subSectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.top, 4)
    }

    private func sectionText(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundColor(.secondary)
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
