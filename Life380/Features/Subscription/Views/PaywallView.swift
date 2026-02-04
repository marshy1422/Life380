import SwiftUI
import StoreKit

/// Main paywall view for subscription purchases
struct PaywallView: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: PlanType = .annual
    @State private var selectedTier: SubscriptionTier = .plus
    @State private var introOfferEligibility: [String: Bool] = [:]

    enum PlanType {
        case monthly, annual, lifetime
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Tier selector
                    tierSelector

                    // Features list
                    featuresSection

                    // Plan selector
                    planSelector

                    // Purchase button
                    purchaseButton

                    // Restore purchases
                    restoreButton

                    // Legal
                    legalText
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(subscriptionService.errorMessage != nil)) {
                Button("OK") {
                    // Clear error handled by service
                }
            } message: {
                Text(subscriptionService.errorMessage ?? "")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Upgrade to Life380+")
                .font(.title)
                .fontWeight(.bold)

            Text("Keep your family safer with premium features")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Comparison with Life360
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Save 50%+ vs Life360")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.15))
            .cornerRadius(20)
        }
        .padding(.vertical)
    }

    // MARK: - Tier Selector

    private var tierSelector: some View {
        HStack(spacing: 12) {
            TierButton(
                tier: .plus,
                isSelected: selectedTier == .plus,
                price: subscriptionService.price(for: "life380_plus_annual") ?? "$35.99/yr"
            ) {
                selectedTier = .plus
            }

            TierButton(
                tier: .family,
                isSelected: selectedTier == .family,
                price: subscriptionService.price(for: "life380_family_annual") ?? "$59.99/yr",
                badge: "Best for Families"
            ) {
                selectedTier = .family
            }
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's Included")
                .font(.headline)

            let features: [PremiumFeature] = selectedTier == .plus
                ? [.crashDetection, .driveSafety, .locationHistory, .unlimitedCircles, .placeAlerts, .sosButton]
                : PremiumFeature.allCases

            ForEach(features, id: \.rawValue) { feature in
                FeatureRow(feature: feature)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Plan Selector

    private var planSelector: some View {
        VStack(spacing: 12) {
            Text("Choose Your Plan")
                .font(.headline)

            VStack(spacing: 8) {
                // Annual (Best Value)
                PlanOption(
                    title: "Annual",
                    price: annualPrice,
                    subtitle: "Save 40%",
                    isSelected: selectedPlan == .annual,
                    badge: "Best Value"
                ) {
                    selectedPlan = .annual
                }

                // Monthly
                PlanOption(
                    title: "Monthly",
                    price: monthlyPrice,
                    subtitle: "Cancel anytime",
                    isSelected: selectedPlan == .monthly
                ) {
                    selectedPlan = .monthly
                }

                // Lifetime (Launch Special)
                PlanOption(
                    title: "Lifetime",
                    price: lifetimePrice,
                    subtitle: "One-time purchase",
                    isSelected: selectedPlan == .lifetime,
                    badge: "Launch Special"
                ) {
                    selectedPlan = .lifetime
                }
            }
        }
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        VStack(spacing: 8) {
            // Show intro offer terms if eligible
            if let introDescription = currentIntroOfferDescription, isEligibleForCurrentIntroOffer {
                Text(introDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await purchase()
                }
            } label: {
                HStack {
                    if subscriptionService.purchaseInProgress {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(purchaseButtonTitle)
                            .fontWeight(.semibold)
                    }
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
            .disabled(subscriptionService.purchaseInProgress)
        }
        .task {
            await checkIntroOfferEligibility()
        }
    }

    private var purchaseButtonTitle: String {
        if selectedPlan == .lifetime {
            return "Purchase Lifetime"
        }
        if isEligibleForCurrentIntroOffer {
            return "Start Free Trial"
        }
        return "Continue"
    }

    private var isEligibleForCurrentIntroOffer: Bool {
        introOfferEligibility[currentProductId] ?? false
    }

    private var currentIntroOfferDescription: String? {
        subscriptionService.introOfferDescription(for: currentProductId)
    }

    private func checkIntroOfferEligibility() async {
        for productId in ["life380_plus_monthly", "life380_plus_annual", "life380_family_monthly", "life380_family_annual"] {
            let eligible = await subscriptionService.isEligibleForIntroOffer(productId: productId)
            introOfferEligibility[productId] = eligible
        }
    }

    // MARK: - Restore Button

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task {
                await subscriptionService.restorePurchases()
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }

    // MARK: - Legal

    private var legalText: some View {
        VStack(spacing: 8) {
            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. You can manage and cancel your subscriptions in your App Store account settings.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                if let termsURL = URL(string: "https://life380.app/terms") {
                    Link("Terms of Service", destination: termsURL)
                }
                if let privacyURL = URL(string: "https://life380.app/privacy") {
                    Link("Privacy Policy", destination: privacyURL)
                }
            }
            .font(.caption2)
        }
        .padding(.top)
    }

    // MARK: - Computed Properties

    private var monthlyPrice: String {
        let productId = selectedTier == .plus ? "life380_plus_monthly" : "life380_family_monthly"
        return subscriptionService.price(for: productId) ?? (selectedTier == .plus ? "$4.99/mo" : "$7.99/mo")
    }

    private var annualPrice: String {
        let productId = selectedTier == .plus ? "life380_plus_annual" : "life380_family_annual"
        return subscriptionService.price(for: productId) ?? (selectedTier == .plus ? "$35.99/yr" : "$59.99/yr")
    }

    private var lifetimePrice: String {
        let productId = selectedTier == .plus ? "life380_plus_lifetime" : "life380_family_lifetime"
        return subscriptionService.price(for: productId) ?? (selectedTier == .plus ? "$99.99" : "$149.99")
    }

    private var currentProductId: String {
        switch selectedPlan {
        case .monthly:
            return selectedTier == .plus ? "life380_plus_monthly" : "life380_family_monthly"
        case .annual:
            return selectedTier == .plus ? "life380_plus_annual" : "life380_family_annual"
        case .lifetime:
            return selectedTier == .plus ? "life380_plus_lifetime" : "life380_family_lifetime"
        }
    }

    // MARK: - Actions

    private func purchase() async {
        let productId: String
        switch selectedPlan {
        case .monthly:
            productId = selectedTier == .plus ? "life380_plus_monthly" : "life380_family_monthly"
        case .annual:
            productId = selectedTier == .plus ? "life380_plus_annual" : "life380_family_annual"
        case .lifetime:
            productId = selectedTier == .plus ? "life380_plus_lifetime" : "life380_family_lifetime"
        }

        let success = await subscriptionService.purchase(productId)
        if success {
            dismiss()
        }
    }
}

// MARK: - Tier Button

struct TierButton: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let price: String
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let badge = badge {
                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(8)
                }

                Text(tier.displayName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .primary : .secondary)

                Text(price)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let feature: PremiumFeature

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(feature.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}

// MARK: - Plan Option

struct PlanOption: View {
    let title: String
    let price: String
    let subtitle: String
    let isSelected: Bool
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)

                        if let badge = badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badge == "Best Value" ? Color.green : Color.orange)
                                .cornerRadius(6)
                        }
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(price)
                    .font(.headline)
                    .foregroundColor(.primary)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
}
