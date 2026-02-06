import SwiftUI

/// View for crash detection settings and emergency contacts
struct CrashDetectionView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "car.side.rear.and.collision.and.car.side.front")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Crash Detection")
                .font(.title)
                .fontWeight(.bold)

            Text("Automatically detect potential vehicle crashes and alert your emergency contacts with your location.")
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
        .navigationTitle("Crash Detection")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CrashDetectionView()
    }
}
