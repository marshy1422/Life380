import SwiftUI

/// Shows current subscription status in Settings
struct SubscriptionStatusView: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var showingPaywall = false
    @State private var showingManageSubscription = false

    var body: some View {
        List {
            // Current Plan Section
            Section {
                currentPlanCard
            }

            // Features Section
            Section {
                ForEach(PremiumFeature.allCases, id: \.rawValue) { feature in
                    featureRow(feature)
                }
            } header: {
                Text("Premium Features")
            }

            // Manage Section
            if subscriptionService.isPremium {
                Section {
                    Button {
                        showingManageSubscription = true
                    } label: {
                        Label("Manage Subscription", systemImage: "gear")
                    }

                    Button {
                        Task {
                            await subscriptionService.restorePurchases()
                        }
                    } label: {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .navigationTitle("Subscription")
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .manageSubscriptionsSheet(isPresented: $showingManageSubscription)
    }

    // MARK: - Current Plan Card

    private var currentPlanCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscriptionService.currentTier.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    if subscriptionService.isLifetime {
                        Text("Lifetime Access")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    } else if let expiration = subscriptionService.expirationDate {
                        Text("Renews \(expiration, style: .date)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if subscriptionService.currentTier == .free {
                        Text("Limited features")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                tierIcon
            }

            if subscriptionService.currentTier == .free {
                Button {
                    showingPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Upgrade to Premium")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            } else if subscriptionService.currentTier == .plus {
                Button {
                    showingPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Upgrade to Family")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var tierIcon: some View {
        ZStack {
            Circle()
                .fill(tierColor.opacity(0.2))
                .frame(width: 60, height: 60)

            Image(systemName: tierIconName)
                .font(.title)
                .foregroundColor(tierColor)
        }
    }

    private var tierColor: Color {
        switch subscriptionService.currentTier {
        case .free: return .gray
        case .plus: return .blue
        case .family: return .purple
        }
    }

    private var tierIconName: String {
        switch subscriptionService.currentTier {
        case .free: return "person.fill"
        case .plus: return "star.fill"
        case .family: return "person.3.fill"
        }
    }

    // MARK: - Feature Row

    private func featureRow(_ feature: PremiumFeature) -> some View {
        HStack {
            Image(systemName: feature.icon)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.rawValue)
                    .font(.subheadline)

                Text(feature.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if subscriptionService.hasAccess(to: feature) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button {
                    showingPaywall = true
                } label: {
                    Text("Unlock")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Feature Gate View

/// Shows when user tries to access a premium feature
struct FeatureGateView: View {
    let feature: PremiumFeature
    @State private var showingPaywall = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: feature.icon)
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(feature.rawValue)
                .font(.title)
                .fontWeight(.bold)

            Text(feature.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 8) {
                Text("This feature requires")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(feature.requiredTier.displayName)
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)

            Spacer()

            Button {
                showingPaywall = true
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Upgrade Now")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .padding(.horizontal)

            Button("Maybe Later") {
                dismiss()
            }
            .foregroundColor(.secondary)
            .padding(.bottom)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
}

// MARK: - Premium Feature Modifier

struct PremiumFeatureModifier: ViewModifier {
    let feature: PremiumFeature
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var showingGate = false

    func body(content: Content) -> some View {
        if subscriptionService.hasAccess(to: feature) {
            content
        } else {
            Button {
                showingGate = true
            } label: {
                content
                    .overlay(
                        ZStack {
                            Color.black.opacity(0.5)

                            VStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .font(.title)
                                Text(feature.requiredTier.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                        }
                    )
            }
            .sheet(isPresented: $showingGate) {
                FeatureGateView(feature: feature)
            }
        }
    }
}

extension View {
    /// Gates a view behind a premium feature
    func requiresPremium(_ feature: PremiumFeature) -> some View {
        modifier(PremiumFeatureModifier(feature: feature))
    }
}

// MARK: - Subscription Badge (for Settings row)

struct SubscriptionBadge: View {
    @StateObject private var subscriptionService = SubscriptionService.shared

    var body: some View {
        Text(subscriptionService.currentTier.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(badgeTextColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.2))
            .cornerRadius(8)
    }

    private var badgeColor: Color {
        switch subscriptionService.currentTier {
        case .free: return .gray
        case .plus: return .blue
        case .family: return .purple
        }
    }

    private var badgeTextColor: Color {
        switch subscriptionService.currentTier {
        case .free: return .secondary
        case .plus: return .blue
        case .family: return .purple
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionStatusView()
    }
}
