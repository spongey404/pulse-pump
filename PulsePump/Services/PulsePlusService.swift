import Foundation
import StoreKit
import Observation

enum PulsePlusFeature: String, CaseIterable, Identifiable {
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
        case .smartWeightSuggestions: "Smart Weight Suggestions"
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
class PulsePlusService {
    private(set) var isSubscribed = false
    private(set) var currentSubscription: Product?
    private(set) var availableProducts: [Product] = []
    private(set) var isLoading = false

    static let monthlyProductId = "com.pulse.PulsePump.monthly"
    static let yearlyProductId = "com.pulse.PulsePump.yearly"

    private var updateListenerTask: Task<Void, Never>?

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
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshSubscriptionStatus()
            return true
        case .userCancelled:
            return false
        case .pending:
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
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productID == Self.monthlyProductId ||
                   transaction.productID == Self.yearlyProductId {
                    foundActive = true
                    currentSubscription = availableProducts.first { $0.id == transaction.productID }
                }
            }
        }
        isSubscribed = foundActive
    }

    var isInFreeTrial: Bool {
        guard let installDate = UserDefaults.standard.object(forKey: "appInstallDate") as? Date else {
            // First launch — record install date
            UserDefaults.standard.set(Date(), forKey: "appInstallDate")
            return true
        }
        let daysSinceInstall = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
        return daysSinceInstall <= 14
    }

    var trialDaysRemaining: Int {
        guard let installDate = UserDefaults.standard.object(forKey: "appInstallDate") as? Date else { return 14 }
        let daysSinceInstall = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
        return max(0, 14 - daysSinceInstall)
    }

    func hasAccess(to feature: PulsePlusFeature) -> Bool {
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
