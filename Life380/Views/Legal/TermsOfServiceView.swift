import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terms of Service")
                    .font(.title.bold())
                    .padding(.bottom, 8)

                Text("Last updated: \(formattedDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Group {
                    sectionTitle("1. Acceptance of Terms")
                    sectionText("""
                    By downloading, installing, or using Life380 ("the App"), you agree to be bound by these Terms of Service. If you do not agree to these terms, do not use the App.
                    """)

                    sectionTitle("2. Description of Service")
                    sectionText("""
                    Life380 is a family location sharing application that allows users to share their real-time location with family members within a private circle. The service includes location tracking, place alerts, and family communication features.
                    """)

                    sectionTitle("3. User Accounts")
                    sectionText("""
                    You must create an account to use Life380. You are responsible for maintaining the confidentiality of your account credentials and for all activities under your account. You must be at least 13 years old to create an account. Users under 18 must have parental consent.
                    """)

                    sectionTitle("4. Privacy and Data Collection")
                    sectionText("""
                    We collect location data, device information, and usage data as described in our Privacy Policy. Location data is shared only with members of your circle. You can control location sharing through the app settings.
                    """)

                    sectionTitle("5. Acceptable Use")
                    sectionText("""
                    You agree not to:
                    • Use the App to track anyone without their consent
                    • Share location data outside of the App
                    • Attempt to access other users' data without authorization
                    • Use the App for any illegal purpose
                    • Interfere with the App's operation
                    """)
                }

                Group {
                    sectionTitle("6. Location Sharing Consent")
                    sectionText("""
                    All circle members must consent to location sharing. By joining a circle, you consent to sharing your location with other circle members. You may disable location sharing at any time through the app settings.
                    """)

                    sectionTitle("7. Account Deletion")
                    sectionText("""
                    You may delete your account at any time through the App settings. Upon deletion, we will remove your personal data as described in our Privacy Policy. Some data may be retained as required by law.
                    """)

                    sectionTitle("8. Disclaimers")
                    sectionText("""
                    The App is provided "as is" without warranties of any kind. We do not guarantee the accuracy of location data. The App should not be used as the sole means of ensuring safety.
                    """)

                    sectionTitle("9. Limitation of Liability")
                    sectionText("""
                    To the maximum extent permitted by law, we shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the App.
                    """)

                    sectionTitle("10. Changes to Terms")
                    sectionText("""
                    We may update these terms from time to time. Continued use of the App after changes constitutes acceptance of the new terms.
                    """)

                    sectionTitle("11. Contact")
                    sectionText("""
                    For questions about these Terms, please contact us at support@life380.com.
                    """)
                }
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
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

    private func sectionText(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundColor(.secondary)
    }
}

#Preview {
    NavigationStack {
        TermsOfServiceView()
    }
}
