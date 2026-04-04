import Foundation
import StoreKit
import Observation

enum PulsePlusFeature {
    case advancedAnalytics
    case customChallenges
    case cloudSync
    case prioritySupport
    case exportData
    case unlimitedEquipmentProfiles
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

    func hasAccess(to feature: PulsePlusFeature) -> Bool {
        isSubscribed
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
