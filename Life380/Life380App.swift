import SwiftUI
import FirebaseCore

@main
struct Life380App: App {
    @StateObject private var authService = AuthenticationService()
    @StateObject private var firestoreService = FirestoreService.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var locationManager = PrecisionLocationManager()  // Shared location manager

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(firestoreService)
                .environmentObject(notificationService)
                .environmentObject(locationManager)  // Shared location manager
                .task {
                    // Request notification permissions and set up categories
                    await setupNotifications()
                }
        }
    }

    private func setupNotifications() async {
        // Set up notification action categories
        notificationService.setupNotificationCategories()

        // Request authorization
        _ = await notificationService.requestAuthorization()
    }
}

struct RootView: View {
    @EnvironmentObject var authService: AuthenticationService

    var body: some View {
        Group {
            if authService.isAuthenticated {
                ContentView()
            } else {
                LoginView()
            }
        }
    }
}
