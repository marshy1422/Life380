import SwiftUI

/// View showing drive safety scores and reports
struct DriveSafetyView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "gauge.with.needle")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Drive Safety")
                .font(.title)
                .fontWeight(.bold)

            Text("Track your driving habits and get safety scores based on your braking, acceleration, and speed patterns.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Spacer()

            Text("Coming Soon")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding()
                .background(Color.gray.opacity(0.15))
                .cornerRadius(12)

            Spacer()
        }
        .padding()
        .navigationTitle("Drive Safety")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DriveSafetyView()
    }
}
