import SwiftUI
import MapKit

/// Container view for the home/map screen
struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var firestoreService: FirestoreService
    @EnvironmentObject var locationManager: PrecisionLocationManager

    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        ZStack {
            // Map takes full screen
            MapView()
                .ignoresSafeArea(edges: .top)

            // Overlay UI elements
            VStack {
                // Top bar with search and filters
                MapOverlayView()
                    .padding(.top, 8)

                Spacer()
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthService())
        .environmentObject(FirestoreService.shared)
        .environmentObject(PrecisionLocationManager())
}
