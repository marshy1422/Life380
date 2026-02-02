import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @EnvironmentObject var locationManager: PrecisionLocationManager  // Use shared instance
    @State private var selectedTab = 0
    @State private var hasUpdatedInitialLocation = false
    @State private var memberToLocate: UserProfile?

    var body: some View {
        TabView(selection: $selectedTab) {
            MapView(memberToLocate: $memberToLocate)
                .tag(0)
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Map")
                }

            PlacesView()
                .tag(1)
                .tabItem {
                    Image(systemName: "mappin.circle.fill")
                    Text("Places")
                }

            InsightsView()
                .tag(2)
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("Insights")
                }

            CircleView(memberToLocate: $memberToLocate, selectedTab: $selectedTab)
                .tag(3)
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Circle")
                }

            SettingsView()
                .tag(4)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .onAppear {
            firestoreService.listenToUserProfile()
            firestoreService.listenToCircles()

            // Request location permission and start tracking immediately on sign-in
            locationManager.requestPermission()
            locationManager.startTracking()
        }
        .onChange(of: locationManager.currentLocation) { _, newLocation in
            // Update Firestore with actual location as soon as we have it
            // This fixes the bug where users see 0,0 (Null Island) after sign-in
            if !hasUpdatedInitialLocation, let location = newLocation {
                hasUpdatedInitialLocation = true
                Task {
                    await firestoreService.updateUserLocation(
                        latitude: location.latitude,
                        longitude: location.longitude,
                        batteryLevel: getBatteryLevel(),
                        accuracy: location.horizontalAccuracy,
                        floor: location.floor
                    )
                }
            }
        }
    }

    private func getBatteryLevel() -> Int {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return level < 0 ? 100 : Int(level * 100)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationService())
        .environmentObject(FirestoreService.shared)
        .environmentObject(PrecisionLocationManager())
}
