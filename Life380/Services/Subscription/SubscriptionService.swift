import Foundation
import StoreKit

/// Subscription tiers available in Life380
enum SubscriptionTier: String, CaseIterable {
    case free = "free"
    case plus = "life380_plus"
    case family = "life380_family"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .plus: return "Life380+"
        case .family: return "Life380 Family"
        }
    }

    var monthlyProductId: String? {
        switch self {
        case .free: return nil
        case .plus: return "life380_plus_monthly"
        case .family: return "life380_family_monthly"
        }
    }

    var annualProductId: String? {
        switch self {
        case .free: return nil
        case .plus: return "life380_plus_annual"
        case .family: return "life380_family_annual"
        }
    }

    var lifetimeProductId: String? {
        switch self {
        case .free: return nil
        case .plus: return "life380_plus_lifetime"
        case .family: return "life380_family_lifetime"
        }
    }
}

/// Features that can be gated behind subscriptions
enum PremiumFeature: String, CaseIterable {
    case crashDetection = "Crash Detection"
    case driveSafety = "Drive Safety Reports"
    case locationHistory = "30-Day Location History"
    case unlimitedCircles = "Unlimited Circles"
    case placeAlerts = "Place Alerts"
    case sosButton = "SOS Button"
    case familyDashboard = "Family Dashboard"
    case prioritySupport = "Priority Support"
    case dataExport = "Data Export"

    var requiredTier: SubscriptionTier {
        switch self {
        case .crashDetection, .driveSafety, .locationHistory,
             .unlimitedCircles, .placeAlerts, .sosButton:
            return .plus
        case .familyDashboard, .prioritySupport, .dataExport:
            return .family
        }
    }

    var icon: String {
        switch self {
        case .crashDetection: return "car.side.rear.and.collision.and.car.side.front"
        case .driveSafety: return "gauge.with.needle"
        case .locationHistory: return "clock.arrow.circlepath"
        case .unlimitedCircles: return "person.3.fill"
        case .placeAlerts: return "bell.badge.fill"
        case .sosButton: return "sos"
        case .familyDashboard: return "rectangle.grid.2x2.fill"
        case .prioritySupport: return "star.fill"
        case .dataExport: return "square.and.arrow.up"
        }
    }

    var description: String {
        switch self {
        case .crashDetection: return "Automatic crash detection with emergency alerts"
        case .driveSafety: return "Weekly driving safety scores and reports"
        case .locationHistory: return "View where family members have been"
        case .unlimitedCircles: return "Create as many circles as you need"
        case .placeAlerts: return "Get notified when family arrives or leaves"
        case .sosButton: return "One-tap emergency alert to your circle"
        case .familyDashboard: return "Overview of all family members at a glance"
        case .prioritySupport: return "Get help faster when you need it"
        case .dataExport: return "Export your location data anytime"
        }
    }
}

/// Manages subscriptions and in-app purchases
@MainActor
class SubscriptionService: ObservableObject {

    static let shared = SubscriptionService()

    // MARK: - Published State

    @Published private(set) var currentTier: SubscriptionTier = .free
    @Published private(set) var isLifetime: Bool = false
    @Published private(set) var expirationDate: Date?
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseInProgress: Bool = false
    @Published private(set) var errorMessage: String?

    // Billing state tracking (StoreKit 2 compliance)
    @Published private(set) var isInGracePeriod: Bool = false
    @Published private(set) var isInBillingRetry: Bool = false
    @Published private(set) var subscriptionRenewalState: String = ""

    // MARK: - Product IDs

    private let productIds: Set<String> = [
        "life380_plus_monthly",
        "life380_plus_annual",
        "life380_plus_lifetime",
        "life380_family_monthly",
        "life380_family_annual",
        "life380_family_lifetime"
    ]

    // MARK: - Initialization

    private init() {
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
            await listenForTransactions()
        }
    }

    // MARK: - Public API

    /// Check if a feature is available for the current subscription
    func hasAccess(to feature: PremiumFeature) -> Bool {
        switch currentTier {
        case .free:
            return false
        case .plus:
            return feature.requiredTier == .plus || feature.requiredTier == .free
        case .family:
            return true // Family has access to everything
        }
    }

    /// Check if user has any premium subscription
    var isPremium: Bool {
        currentTier != .free
    }

    /// Get the price for a product
    func price(for productId: String) -> String? {
        products.first { $0.id == productId }?.displayPrice
    }

    /// Get product by ID
    func product(for productId: String) -> Product? {
        products.first { $0.id == productId }
    }

    /// Check if user is eligible for introductory offer on a product
    func isEligibleForIntroOffer(productId: String) async -> Bool {
        guard let product = products.first(where: { $0.id == productId }),
              let subscription = product.subscription else {
            return false
        }
        return await subscription.isEligibleForIntroOffer
    }

    /// Get introductory offer details for a product
    func introductoryOffer(for productId: String) -> Product.SubscriptionOffer? {
        guard let product = products.first(where: { $0.id == productId }),
              let subscription = product.subscription else {
            return nil
        }
        return subscription.introductoryOffer
    }

    /// Get formatted intro offer description (e.g., "2 weeks free, then $4.99/month")
    func introOfferDescription(for productId: String) -> String? {
        guard let product = products.first(where: { $0.id == productId }),
              let subscription = product.subscription,
              let offer = subscription.introductoryOffer else {
            return nil
        }

        let periodUnit: String
        switch offer.period.unit {
        case .day: periodUnit = offer.period.value == 1 ? "day" : "days"
        case .week: periodUnit = offer.period.value == 1 ? "week" : "weeks"
        case .month: periodUnit = offer.period.value == 1 ? "month" : "months"
        case .year: periodUnit = offer.period.value == 1 ? "year" : "years"
        @unknown default: periodUnit = "period"
        }

        let offerDuration = "\(offer.period.value) \(periodUnit)"

        switch offer.paymentMode {
        case .freeTrial:
            return "\(offerDuration) free trial, then \(product.displayPrice)"
        case .payAsYouGo:
            return "\(offer.displayPrice) for \(offerDuration), then \(product.displayPrice)"
        case .payUpFront:
            return "\(offer.displayPrice) for \(offerDuration) upfront"
        default:
            return nil
        }
    }

    /// Purchase a subscription
    func purchase(_ productId: String) async -> Bool {
        guard let product = products.first(where: { $0.id == productId }) else {
            errorMessage = "Product not found"
            return false
        }

        purchaseInProgress = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updateSubscriptionStatus()
                await transaction.finish()
                purchaseInProgress = false
                return true

            case .userCancelled:
                purchaseInProgress = false
                return false

            case .pending:
                errorMessage = "Purchase is pending approval"
                purchaseInProgress = false
                return false

            @unknown default:
                purchaseInProgress = false
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            purchaseInProgress = false
            return false
        }
    }

    /// Restore previous purchases
    func restorePurchases() async {
        purchaseInProgress = true

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }

        purchaseInProgress = false
    }

    // MARK: - Private Methods

    private func loadProducts() async {
        do {
            products = try await Product.products(for: productIds)
            products.sort { $0.price < $1.price }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }

    private func updateSubscriptionStatus() async {
        var highestTier: SubscriptionTier = .free
        var latestExpiration: Date?
        var hasLifetime = false
        var inGracePeriod = false
        var inBillingRetry = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            // Check for revocation (refunded purchases)
            if transaction.revocationDate != nil {
                // Transaction was refunded - skip it, don't grant access
                continue
            }

            // Determine tier from product ID
            let tier: SubscriptionTier
            if transaction.productID.contains("family") {
                tier = .family
            } else if transaction.productID.contains("plus") {
                tier = .plus
            } else {
                continue
            }

            // Check if lifetime
            if transaction.productID.contains("lifetime") {
                hasLifetime = true
            }

            // Track highest tier
            if tier == .family || (tier == .plus && highestTier == .free) {
                highestTier = tier
            }

            // Track expiration
            if let expiration = transaction.expirationDate {
                if let latest = latestExpiration {
                    if expiration > latest {
                        latestExpiration = expiration
                    }
                } else {
                    latestExpiration = expiration
                }
            }
        }

        // Check subscription renewal state for billing issues (StoreKit 2)
        await checkSubscriptionRenewalState(&inGracePeriod, &inBillingRetry)

        currentTier = highestTier
        expirationDate = latestExpiration
        isLifetime = hasLifetime
        isInGracePeriod = inGracePeriod
        isInBillingRetry = inBillingRetry

        // Save to UserDefaults for offline access
        UserDefaults.standard.set(currentTier.rawValue, forKey: "subscription.tier")
        UserDefaults.standard.set(isLifetime, forKey: "subscription.lifetime")
        if let expiration = expirationDate {
            UserDefaults.standard.set(expiration, forKey: "subscription.expiration")
        }
    }

    /// Check subscription renewal state for billing retry and grace period
    private func checkSubscriptionRenewalState(_ inGracePeriod: inout Bool, _ inBillingRetry: inout Bool) async {
        for product in products where product.type == .autoRenewable {
            guard let subscription = product.subscription else { continue }

            do {
                let statuses = try await subscription.status
                for status in statuses {
                    switch status.state {
                    case .inGracePeriod:
                        // User is in grace period - still grant access but warn them
                        inGracePeriod = true
                        subscriptionRenewalState = "Your subscription payment failed. Please update your payment method to avoid losing access."

                    case .inBillingRetryPeriod:
                        // Apple is retrying billing - still grant access
                        inBillingRetry = true
                        subscriptionRenewalState = "We're having trouble processing your payment. Please check your payment method."

                    case .revoked:
                        // Subscription was revoked (refunded)
                        subscriptionRenewalState = "Your subscription has been cancelled."

                    case .expired:
                        // Subscription expired normally
                        subscriptionRenewalState = ""

                    case .subscribed:
                        // Active subscription
                        subscriptionRenewalState = ""

                    default:
                        break
                    }
                }
            } catch {
                // Error checking status - continue with current entitlements
            }
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await updateSubscriptionStatus()
            await transaction.finish()
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Errors

enum SubscriptionError: LocalizedError {
    case verificationFailed
    case productNotFound
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Purchase verification failed"
        case .productNotFound:
            return "Product not found"
        case .purchaseFailed:
            return "Purchase failed"
        }
    }
}
