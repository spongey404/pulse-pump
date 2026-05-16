import SwiftUI
import StoreKit

struct PulsePlusView: View {
    var onBack: (() -> Void)? = nil
    @State private var service = PulsePlusService()
    @State private var billingPeriod: BillingPeriod = .annual
    @State private var purchaseError: String?
    @State private var showError = false

    enum BillingPeriod { case monthly, annual }

    private var features: [(icon: String, title: String, sub: String)] {
        [
            ("chart.line.uptrend.xyaxis", "Smart Predictions", "AI-powered workout suggestions"),
            ("icloud.and.arrow.up", "Cloud Sync", "Sync across all your devices"),
            ("chart.bar.xaxis", "Advanced Analytics", "MET-based calorie tracking + trends"),
            ("waveform.path.ecg.rectangle", "Weekly Recaps", "Automated Monday summaries"),
            ("person.2", "Friend Challenges", "Compete with your training partners"),
            ("arrow.triangle.2.circlepath", "Import / Export", "Bring your data from any app"),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            pulsePlusHeader

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    if service.isSubscribed {
                        activeSection
                    } else if service.isInFreeTrial {
                        trialSection
                    } else {
                        billingToggleSection
                    }
                    featureListSection
                    if !service.isSubscribed {
                        ctaSection
                    }
                    restoreSection
                    Color.clear.frame(height: 40)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .task {
            service.startListening()
            await service.loadProducts()
            await service.refreshSubscriptionStatus()
        }
        .onDisappear { service.stopListening() }
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(purchaseError ?? "Something went wrong.")
        }
    }

    // MARK: - Header

    private var pulsePlusHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                            .frame(width: 36, height: 36)
                            .background(Color.surf2)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                Text("PULSE+")
                    .font(.archivo(24, weight: .black))
                    .tracking(0.5)
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
        .background(Color.canvasBg)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.pumpAccent)
                    .frame(width: 72, height: 72)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                Text("UNLOCK PULSE+")
                    .font(.archivo(28, weight: .black))
                    .tracking(1)
                    .foregroundStyle(Color.inkPrimary)
                    .multilineTextAlignment(.center)
                Text("Train smarter. Track deeper.\nShare with your crew.")
                    .font(.archivo(14))
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(Color.surf)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: - Active

    private var activeSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.signalUp)
            VStack(alignment: .leading, spacing: 2) {
                Text("PULSE+ ACTIVE")
                    .font(.spaceMono(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.signalUp)
                Text("Thank you for subscribing.")
                    .font(.archivo(13))
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.signalUp.opacity(0.08))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: - Trial

    private var trialSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.prGold)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(service.trialDaysRemaining) DAYS LEFT IN TRIAL")
                    .font(.spaceMono(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.prGold)
                Text("Subscribe to keep access after the trial.")
                    .font(.archivo(13))
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.prGold.opacity(0.08))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: - Billing Toggle

    private var billingToggleSection: some View {
        VStack(spacing: 12) {
            Text("BILLING PERIOD")
                .font(.spaceMono(9))
                .tracking(1.5)
                .foregroundStyle(Color.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                billingPill(.monthly, label: "MONTHLY")
                billingPill(.annual, label: "ANNUAL\n14% OFF")
            }
            .background(Color.surf2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.dsHairLine, lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.canvasBg)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func billingPill(_ period: BillingPeriod, label: String) -> some View {
        let active = billingPeriod == period
        return Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { billingPeriod = period } } label: {
            Text(label)
                .font(.spaceMono(10, weight: active ? .bold : .regular))
                .tracking(1)
                .foregroundStyle(active ? .white : Color.inkMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(active ? Color.pumpAccent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Feature List

    private var featureListSection: some View {
        VStack(spacing: 0) {
            Text("WHAT'S INCLUDED")
                .font(.spaceMono(9))
                .tracking(1.5)
                .foregroundStyle(Color.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ForEach(features, id: \.title) { feature in
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.pumpAccent.opacity(0.08))
                                .frame(width: 36, height: 36)
                            Image(systemName: feature.icon)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.pumpAccent)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(feature.title)
                                .font(.archivo(14, weight: .semibold))
                                .foregroundStyle(Color.inkPrimary)
                            Text(feature.sub)
                                .font(.spaceMono(9))
                                .tracking(0.3)
                                .foregroundStyle(Color.inkMuted)
                        }
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.signalUp)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Rectangle().fill(Color.dsHairLine).frame(height: 1)
                }
                .background(Color.canvasBg)
            }
        }
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 10) {
            if service.isLoading {
                ProgressView()
                    .frame(height: 52)
            } else if let product = matchedProduct {
                Button {
                    Task { await purchaseProduct(product) }
                } label: {
                    VStack(spacing: 2) {
                        Text("SUBSCRIBE · \(product.displayPrice)")
                            .font(.archivo(20, weight: .black))
                            .tracking(2)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.pumpAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))
            } else {
                Text("Subscriptions unavailable")
                    .font(.spaceMono(11))
                    .foregroundStyle(Color.inkMuted)
                    .frame(height: 52)
            }

            Text("Cancel anytime. Billed \(billingPeriod == .annual ? "annually" : "monthly").")
                .font(.spaceMono(9))
                .tracking(0.5)
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color.canvasBg)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private var matchedProduct: Product? {
        service.availableProducts.first { product in
            if billingPeriod == .annual {
                return product.subscription?.subscriptionPeriod.unit == .year
            } else {
                return product.subscription?.subscriptionPeriod.unit == .month
            }
        } ?? service.availableProducts.first
    }

    // MARK: - Restore

    private var restoreSection: some View {
        Button {
            Task { await service.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(.spaceMono(10))
                .tracking(0.5)
                .foregroundStyle(Color.inkMuted)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 16)
    }

    // MARK: - Actions

    private func purchaseProduct(_ product: Product) async {
        do {
            let success = try await service.purchase(product)
            if !success { }
        } catch {
            purchaseError = error.localizedDescription
            showError = true
        }
    }
}
