import SwiftUI
import CoreLocation

/// ML Training View - Feature currently disabled
/// Location accuracy is handled by Kalman filtering instead
struct MLTrainingView: View {

    var body: some View {
        List {
            // Status Section
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "brain")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)

                    Text("ML Training Disabled")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Location accuracy is now powered by advanced Kalman filtering, which provides better results without requiring training data.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            // Current Method Section
            Section {
                MLFeatureRow(
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    title: "Kalman Filtering",
                    description: "Active - Smooths GPS noise in real-time"
                )

                MLFeatureRow(
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    title: "Motion-Adaptive",
                    description: "Active - Adjusts accuracy based on movement"
                )

                MLFeatureRow(
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    title: "Apple Fused Location",
                    description: "Active - Uses WiFi, GPS, and cell data"
                )

                MLFeatureRow(
                    icon: "xmark.circle.fill",
                    iconColor: .secondary,
                    title: "Neural Network",
                    description: "Disabled - Kalman filter is more reliable"
                )
            } header: {
                Text("Location Accuracy Methods")
            } footer: {
                Text("Your location accuracy is typically 5-15 meters outdoors and 15-50 meters indoors.")
            }

            // Why Disabled Section
            Section {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        MLExplanationRow(
                            title: "Better Accuracy",
                            description: "Kalman filtering provides consistent 3-5 meter improvement without training."
                        )

                        MLExplanationRow(
                            title: "No Wait Time",
                            description: "Works immediately - no need to collect weeks of data first."
                        )

                        MLExplanationRow(
                            title: "Lower Battery",
                            description: "No background training means better battery life."
                        )

                        MLExplanationRow(
                            title: "More Reliable",
                            description: "Mathematical approach works consistently across all conditions."
                        )
                    }
                    .padding(.vertical, 8)
                } label: {
                    Label("Why was ML training removed?", systemImage: "questionmark.circle")
                }
            }
        }
        .navigationTitle("Location Accuracy")
    }
}

// MARK: - Supporting Views

private struct MLFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MLExplanationRow: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        MLTrainingView()
    }
}
