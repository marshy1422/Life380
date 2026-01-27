import SwiftUI

struct ContentView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MapView()
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

            CircleView()
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
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationService())
        .environmentObject(FirestoreService.shared)
}
