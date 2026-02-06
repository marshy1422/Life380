import SwiftUI
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

@main
struct Life380App: App {
    @StateObject private var authService = AuthenticationService()
    @StateObject private var firestoreService = FirestoreService.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var locationManager = PrecisionLocationManager()  // Shared location manager
    @StateObject private var insightsService = InsightsService.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FirebaseApp.configure()

        // Enable Crashlytics collection
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        // Log app launch
        Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(firestoreService)
                .environmentObject(notificationService)
                .environmentObject(locationManager)  // Shared location manager
                .environmentObject(insightsService)
                .task {
                    // Request notification permissions and set up categories
                    await setupNotifications()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            // Save insights data when app goes to background
            Task {
                await insightsService.saveOnBackground()
            }
            // Save location history
            LocationHistoryService.shared.saveOnBackground()
        case .active:
            // Sync geofences when app becomes active
            if !firestoreService.places.isEmpty {
                locationManager.syncGeofencesWithPlaces(firestoreService.places)
            }
        default:
            break
        }
    }

    private func setupNotifications() async {
        // Set up notification action categories
        notificationService.setupNotificationCategories()

        // Request authorization
        _ = await notificationService.requestAuthorization()
    }

    /// Handle deep links for circle invites
    /// Format: life380://join?code=ABC123
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "life380",
              url.host == "join",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else { return }

        // Post notification to trigger join flow
        NotificationCenter.default.post(
            name: .joinCircleDeepLink,
            object: nil,
            userInfo: ["code": code]
        )
    }
}

// MARK: - Deep Link Notifications

extension Notification.Name {
    static let joinCircleDeepLink = Notification.Name("joinCircleDeepLink")
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
