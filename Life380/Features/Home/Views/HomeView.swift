import SwiftUI
import MapKit

/// Container view for the home/map screen
/// This is a wrapper that delegates to the existing MapView
struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var firestoreService: FirestoreService
    @EnvironmentObject var locationManager: PrecisionLocationManager

    var body: some View {
        // Use the existing MapView which contains all the map functionality
        MapView()
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthService())
        .environmentObject(FirestoreService.shared)
        .environmentObject(PrecisionLocationManager())
}
