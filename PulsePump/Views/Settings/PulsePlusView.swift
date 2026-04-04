import SwiftUI
import StoreKit

struct PulsePlusView: View {
    @State private var service = PulsePlusService()
    @State private var purchaseError: String?
    @State private var showError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                featuresSection
                productsSection
                restoreButton
            }
            .padding()
        }
        .navigationTitle("Pulse+")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            service.startListening()
            await service.loadProducts()
            await service.refreshSubscriptionStatus()
        }
        .onDisappear {
            service.stopListening()
        }
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(purchaseError ?? "Something went wrong.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.pumpPrimary)

            Text("Pulse+")
                .font(.title.weight(.bold))

            if service.isSubscribed {
                Label("Active", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline.weight(.medium))
            } else if service.isInFreeTrial {
                Text("\(service.trialDaysRemaining) days left in free trial")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
            } else {
                Text("Unlock the full Pulse experience")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What's Included")
                .font(.headline)

            ForEach(PulsePlusFeature.allCases) { feature in
                FeatureRow(icon: feature.icon, title: feature.displayName, description: "")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Products

    private var productsSection: some View {
        VStack(spacing: 12) {
            if service.isLoading {
                ProgressView()
            } else if service.availableProducts.isEmpty {
                Text("Subscriptions unavailable")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(service.availableProducts) { product in
                    SubscriptionCard(product: product, isSubscribed: service.isSubscribed) {
                        await purchaseProduct(product)
                    }
                }
            }
        }
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task {
                await service.restorePurchases()
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    // MARK: - Actions

    private func purchaseProduct(_ product: Product) async {
        do {
            let success = try await service.purchase(product)
            if !success {
                // User cancelled or pending — no error
            }
        } catch {
            purchaseError = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Supporting Views

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.pumpPrimary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SubscriptionCard: View {
    let product: Product
    let isSubscribed: Bool
    let onPurchase: () async -> Void

    @State private var isPurchasing = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .font(.headline)
                Text(product.displayPrice)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let subscription = product.subscription {
                    Text(periodLabel(subscription.subscriptionPeriod))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSubscribed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    isPurchasing = true
                    Task {
                        await onPurchase()
                        isPurchasing = false
                    }
                } label: {
                    if isPurchasing {
                        ProgressView()
                    } else {
                        Text("Subscribe")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.pumpPrimary)
                .disabled(isPurchasing)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func periodLabel(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .month: period.value == 1 ? "per month" : "every \(period.value) months"
        case .year: period.value == 1 ? "per year" : "every \(period.value) years"
        case .week: period.value == 1 ? "per week" : "every \(period.value) weeks"
        case .day: period.value == 1 ? "per day" : "every \(period.value) days"
        @unknown default: ""
        }
    }
}
