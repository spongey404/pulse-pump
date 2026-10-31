import Foundation
import UIKit
import StoreKit
import Observation

enum SupernovaFeature: String, CaseIterable, Identifiable {
    case advancedAnalytics
    case customChallenges
    case cloudSync
    case prioritySupport
    case exportData
    case unlimitedEquipmentProfiles
    case smartWeightSuggestions
    case advancedSubstitutions
    case advancedBodyCustomization
    case additionalWidgets

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .advancedAnalytics: "Advanced Analytics + Tips"
        case .customChallenges: "Challenges / Competitions"
        case .cloudSync: "Cloud Sync"
        case .prioritySupport: "Priority Support"
        case .exportData: "Data Export"
        case .unlimitedEquipmentProfiles: "Unlimited Equipment Profiles"
        case .smartWeightSuggestions: "Smart weight suggestions"
        case .advancedSubstitutions: "Smart Exercise Substitutions"
        case .advancedBodyCustomization: "Advanced Body Customization"
        case .additionalWidgets: "Additional Home Widgets"
        }
    }

    var icon: String {
        switch self {
        case .advancedAnalytics: "chart.bar.xaxis"
        case .customChallenges: "trophy"
        case .cloudSync: "icloud"
        case .prioritySupport: "headphones"
        case .exportData: "square.and.arrow.up"
        case .unlimitedEquipmentProfiles: "dumbbell"
        case .smartWeightSuggestions: "brain.head.profile"
        case .advancedSubstitutions: "arrow.triangle.2.circlepath"
        case .advancedBodyCustomization: "figure.stand"
        case .additionalWidgets: "rectangle.3.group"
        }
    }
}

@MainActor
@Observable
class SupernovaService {
    private(set) var isSubscribed = false
    /// A message the paywall shows after a purchase that isn't finished (Ask to Buy).
    private(set) var purchaseNotice: String?
    private(set) var currentSubscription: Product?
    private(set) var availableProducts: [Product] = []
    private(set) var isLoading = false
    /// When the current subscription renews (or ends), for the More row's "RENEWS 14 MAR".
    private(set) var renewalDate: Date?
    /// When the membership began (the first purchase of this subscription).
    private(set) var memberSince: Date?
    /// The plan in use: "YEARLY" or "MONTHLY".
    private(set) var planWord = "YEARLY"

    static let monthlyProductId = "com.pulse.PulsePump.monthly"
    static let yearlyProductId = "com.pulse.PulsePump.yearly"

    /// Mirror of `isSubscribed` for code with no view-owned service (e.g. `WorkoutViewModel`).
    static let subscribedMirrorKey = "pulsePlusSubscribedMirror"

    /// Supernova access as the rest of the app defines it: subscribed or inside the free trial.
    static var hasAccess: Bool {
        PreviewMembership.forced ?? (UserDefaults.standard.bool(forKey: subscribedMirrorKey) || isInFreeTrial)
    }

    private var updateListenerTask: Task<Void, Never>?

    /// One listener for the app's whole life (started from `OreApp`): the mirror, accent and widgets learn about a renewal, an
    /// expiry, a refund or a purchase on another device without anyone opening a Supernova screen.
    private static let appMonitor = SupernovaService()
    static func startAppMonitor() {
        appMonitor.startListening()
        Task { await appMonitor.refreshSubscriptionStatus() }
    }

    func startListening() {
        guard updateListenerTask == nil else { return }
        updateListenerTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
    }

    func stopListening() {
        updateListenerTask?.cancel()
        updateListenerTask = nil
    }

    // MARK: - Public API

    func loadProducts() async {
        isLoading = true
        do {
            let products = try await Product.products(for: [
                Self.monthlyProductId,
                Self.yearlyProductId
            ])
            availableProducts = products.sorted { $0.price < $1.price }
        } catch {
            availableProducts = []
        }
        isLoading = false
    }

    func purchase(_ product: Product) async throws -> Bool {
        purchaseNotice = nil
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshSubscriptionStatus()
            return isSubscribed   // false if the purchase didn't show up as an entitlement, so the paywall isn't closed on nothing
        case .userCancelled:
            return false
        case .pending:
            purchaseNotice = "Waiting for approval. Supernova turns on once it is approved."
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshSubscriptionStatus()
    }

    func refreshSubscriptionStatus() async {
        var foundActive = false
        var renewal: Date?
        var since: Date?
        var best: Transaction?
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  transaction.productID == Self.monthlyProductId || transaction.productID == Self.yearlyProductId else { continue }
            foundActive = true
            since = min(since ?? transaction.originalPurchaseDate, transaction.originalPurchaseDate)
            // Both plans can be entitled at once (a switch in progress): the one that runs longest is the plan in use.
            if best == nil || (transaction.expirationDate ?? .distantFuture) > (best?.expirationDate ?? .distantFuture) { best = transaction }
        }
        if let best {
            renewal = best.expirationDate
            planWord = best.productID == Self.yearlyProductId ? "YEARLY" : "MONTHLY"
            currentSubscription = availableProducts.first { $0.id == best.productID }
        }
        renewalDate = renewal
        memberSince = since
        if PreviewMembership.forced == true, since == nil {   // a pretend member has no purchase: say one began at install
            memberSince = TrialAnchor.installDate()
            renewalDate = renewalDate ?? Calendar.current.date(byAdding: .month, value: 5, to: Date())
        }
        isSubscribed = PreviewMembership.forced ?? foundActive   // forced is nil outside DEBUG and preview builds
        UserDefaults.standard.set(isSubscribed, forKey: Self.subscribedMirrorKey)
        AccentStore.shared.refreshMembership()
        WidgetDataService.setSubscribed(PreviewMembership.forced ?? foundActive)
    }

    var isInFreeTrial: Bool { Self.isInFreeTrial }

    static var isInFreeTrial: Bool {
        guard SupernovaTrial.months > 0 else { return false }
        return SupernovaTrial.isActive(installDate: TrialAnchor.installDate(), now: TrialAnchor.trialNow(), months: SupernovaTrial.months)
    }

    var trialDaysRemaining: Int {
        SupernovaTrial.daysRemaining(installDate: TrialAnchor.installDate(), now: TrialAnchor.trialNow(), months: SupernovaTrial.months)
    }

    /// "$84 / YR" or "$7 / MO": the price of the plan in use, when the product is loaded.
    var planPriceLabel: String? {
        guard let p = currentSubscription ?? availableProducts.first(where: { $0.subscription?.subscriptionPeriod.unit == .year }) else { return nil }
        let unit = p.subscription?.subscriptionPeriod.unit == .month ? "MO" : "YR"
        return p.displayPrice + " / " + unit
    }

    /// "03/26": the membership card's MEMBER SINCE.
    var memberSinceShort: String { memberSince.map { Self.format($0, "MM/yy") } ?? "—" }
    /// "14 MAR 27": the card's RENEWS.
    var renewsShort: String { renewalDate.map { Self.format($0, "d MMM yy").uppercased() } ?? "—" }
    /// "14 MAR 2027".
    var renewsLong: String { renewalDate.map { Self.format($0, "d MMM yyyy").uppercased() } ?? "—" }
    var memberSinceLong: String { memberSince.map { Self.format($0, "d MMM yyyy").uppercased() } ?? "—" }
    /// "MAR 2026".
    var memberSinceMonth: String { memberSince.map { Self.format($0, "MMM yyyy").uppercased() } ?? "—" }

    private static func format(_ d: Date, _ pattern: String) -> String {
        let f = DateFormatter(); f.dateFormat = pattern; f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: d)
    }

    /// The App Store's subscription page, where a membership is managed and cancelled.
    @MainActor func showManageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
    }

    /// "RENEWS 14 MAR" (or "ACTIVE" when the date isn't known), the member's value on the More › Supernova row.
    var statusLabel: String {
        guard let renewalDate else { return "ACTIVE" }
        let f = DateFormatter(); f.dateFormat = "d MMM"
        return "RENEWS " + f.string(from: renewalDate).uppercased()
    }

    func hasAccess(to feature: SupernovaFeature) -> Bool {
        isSubscribed || isInFreeTrial
    }

    // MARK: - Private

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                await transaction.finish()
                await refreshSubscriptionStatus()
            }
        }
    }
}

enum StoreError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed: "Transaction verification failed."
        }
    }
}
