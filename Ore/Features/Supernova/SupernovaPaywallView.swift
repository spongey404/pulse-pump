import SwiftUI
import StoreKit

/// The full-screen Supernova paywall, laid out from the Claude Design file `Supernova Final.dc.html`: glitter behind
/// everything that melts into the dark free strip at the bottom, the wordmark with its gold asterisk (the glitter's
/// gold attractor), four starred features, one white CTA, and the way out ("TRAIN FREE").
///
/// Always dark, like the design. Shown once, at the end of first-run onboarding (`SupernovaPaywallGate`).
struct SupernovaPaywallView: View {
    /// Where it is shown: at the end of first-run onboarding (the design), or opened from More.
    enum Context { case firstRun, more }
    var context: Context = .firstRun
    /// Called after a successful purchase.
    var onSubscribed: () -> Void
    /// "TRAIN FREE →": straight to Home, free. No confirmation, no second paywall.
    var onTrainFree: () -> Void

    @State private var service = SupernovaService()
    @State private var anchor: CGRect?
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    private struct Feature { let name: String; let desc: String }
    private let features = [
        Feature(name: "Smart weight suggestions", desc: "A suggested weight for each set, from your history."),
        Feature(name: "Muscle balance", desc: "See which muscle groups are falling behind."),
        Feature(name: "Detailed analytics", desc: "Deload weeks, trends and tips on your lifts."),
        Feature(name: "Weekly Recap", desc: "One Sunday recap of training, food and steps."),
    ]

    /// Yearly is preselected: it is the plan the CTA buys.
    private var yearly: Product? { service.availableProducts.first { $0.subscription?.subscriptionPeriod.unit == .year } }
    private var perMonth: String {
        guard let yearly else { return "$7" }
        return (yearly.price / 12).formatted(yearly.priceFormatStyle.precision(.fractionLength(0)))
    }

    var body: some View {
        ZStack {
            Color.canvasBg.ignoresSafeArea()
            StarFieldView(variant: "paywall", budget: .paywall, anchor: anchor)
                .ignoresSafeArea()
            // The glitter melts into the free strip: clear to 66%, canvas at 55% by 78%, solid from 89%.
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.66),
                .init(color: Color.canvasBg.opacity(0.55), location: 0.78),
                .init(color: Color.canvasBg, location: 0.89),
                .init(color: Color.canvasBg, location: 1),
            ], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                pitch
                freeStrip
            }
        }
        .onPreferenceChange(SupernovaAsteriskFrameKey.self) { anchor = $0 }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .task {
            service.startListening()
            await service.loadProducts()
        }
        .onDisappear { service.stopListening() }
        .alert("Couldn't start Supernova", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    // MARK: Pitch

    private var pitch: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Rectangle().fill(.white).frame(width: 14, height: 14)
                Text("\(Brand.appName.uppercased()) · \(Brand.membershipName.uppercased()) MEMBERSHIP")
                    .font(.spaceMono(10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white)
            }
            .padding(.top, 18)

            SupernovaWordmark(size: 44, tracking: -0.5, gapEm: SupernovaAsterisk.paywallGapEm)
                .frame(height: 44 * 0.95, alignment: .bottom)
                .padding(.top, 18)

            Text("3 months free across \(Brand.appName), \(Brand.tareName) and \(Brand.driftName).")
                .font(.archivoMedium(17))
                .cssLineHeight(fontName: "Archivo-Medium", size: 17, multiple: 1.35)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            VStack(spacing: 0) {
                ForEach(features, id: \.name) { f in
                    HStack(alignment: .top, spacing: 8) {
                        FourPointStar()
                            .fill(SupernovaAsterisk.color)
                            .frame(width: 14, height: 14)
                            .padding(.top, 3)
                            .frame(width: 20, alignment: .leading)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(f.name)
                                .font(.archivo(15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minHeight: 20, alignment: .leading)
                            Text(f.desc)
                                .font(.archivo(13))
                                .cssLineHeight(fontName: "Archivo-Regular", size: 13, multiple: 1.35)
                                .foregroundStyle(.white.opacity(0.92))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 9)
                    .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.3)).frame(height: 1) }
                }
            }
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.3)).frame(height: 1) }
            .padding(.top, 18)

            Spacer(minLength: 12)

            Button(action: start) {
                Text(isPurchasing ? "…" : "START 3 MONTHS FREE")
                    .font(.archivo(15, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(SupernovaPaywallStyle.ctaInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing)
            .accessibilityIdentifier(AX.supernova.start)

            Text("THEN ~\(perMonth)/MO BILLED YEARLY · NOTHING IS DELETED IF YOU STOP")
                .font(.spaceMono(9))
                .tracking(1.2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.top, 9)

            Button { Task { await service.restorePurchases(); if service.isSubscribed { onSubscribed() } } } label: {
                Text("RESTORE PURCHASES")
                    .font(.spaceMono(8))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AX.supernova.restore)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 22)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: Free strip

    private var freeStrip: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context == .firstRun ? "FREE · TUTORIAL DONE ✓" : "FREE · YOUR PLAN")
                    .font(.spaceMono(9))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.75))
                Text("Logging, PRs and body map stay free.")
                    .font(.archivo(14, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            Button(action: onTrainFree) {
                Text(context == .firstRun ? "TRAIN FREE →" : "NOT NOW →")
                    .font(.spaceMono(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AX.supernova.free)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 26)
    }

    // MARK: Purchase

    private func start() {
        guard let yearly else {
            errorMessage = "Subscriptions aren't available right now. Try again in a moment, or train free for now."
            return
        }
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                if try await service.purchase(yearly) { onSubscribed() }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

extension View {
    /// CSS-style `line-height: <multiple>` for a custom font: lines are at least `size × multiple` tall (text centred in
    /// its line box, like CSS half-leading) and wrapped lines are spaced to match.
    func cssLineHeight(fontName: String, size: CGFloat, multiple: CGFloat) -> some View {
        let target = size * multiple
        let natural = UIFont(name: fontName, size: size)?.lineHeight ?? size * 1.2
        return lineSpacing(target - natural).frame(minHeight: target, alignment: .leading)
    }
}

/// Values taken from the design that have no token of their own.
enum SupernovaPaywallStyle {
    /// The CTA's text: the deep end of the accent ramp (`#0E8FE0`), readable on the white button.
    static let ctaInk = Color(hex: "#0E8FE0")
}
