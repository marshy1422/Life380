import SwiftUI
import MapKit

struct ContentView: View {
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab Content
            TabView(selection: $selectedTab) {
                MapView()
                    .tag(0)

                PlacesView()
                    .tag(1)

                InsightsView()
                    .tag(2)

                CircleView()
                    .tag(3)

                SettingsView()
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            firestoreService.listenToUserProfile()
            firestoreService.listenToCircles()
        }
        .onChange(of: selectedTab) { _, _ in
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var namespace

    let tabs: [(icon: String, label: String)] = [
        ("map.fill", "Map"),
        ("mappin.circle.fill", "Places"),
        ("chart.pie.fill", "Insights"),
        ("person.3.fill", "Circle"),
        ("gearshape.fill", "Settings")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                TabBarButton(
                    icon: tabs[index].icon,
                    label: tabs[index].label,
                    isSelected: selectedTab == index,
                    namespace: namespace
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.sm)
        .padding(.bottom, AppTheme.Spacing.xs)
        .background(.ultraThinMaterial)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: AppTheme.Radius.xl,
                topTrailingRadius: AppTheme.Radius.xl
            )
        )
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -5)
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(AppTheme.Colors.primaryGradient)
                            .frame(width: 64, height: 32)
                            .matchedGeometryEffect(id: "tabBackground", in: namespace)
                    }

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .symbolEffect(.bounce, value: isSelected)
                }
                .frame(height: 32)

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationService())
        .environmentObject(FirestoreService.shared)
}
