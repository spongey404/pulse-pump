import SwiftUI
import StoreKit
import SwiftData

struct PulsePlusView: View {
    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Query(filter: #Predicate<Workout> { !$0.isDraft && $0.deletedAt == nil }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @State private var service = PulsePlusService()
    @State private var billingPeriod: BillingPeriod = .annual
    @State private var purchaseError: String?
    @State private var showError = false
    @State private var predictedName: String?

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

    private func close() { (onBack ?? { dismiss() })() }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroSection
                if !predictionRows.isEmpty { previewCard }
                specSheet
                if service.isSubscribed {
                    activeSection
                } else {
                    if service.isInFreeTrial { trialNote }
                    planSection
                }
                restoreSection
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !service.isSubscribed { ctaDock }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            service.startListening()
            await service.loadProducts()
            await service.refreshSubscriptionStatus()
        }
        .task {
            if let user = users.first {
                predictedName = WorkoutViewModel().predictNextWorkout(user: user, modelContext: modelContext)
            }
        }
        .onDisappear { service.stopListening() }
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(purchaseError ?? "Something went wrong.")
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Rectangle().fill(.white).frame(width: 10, height: 10)
                    Text("PULSE/PUMP · MEMBERSHIP")
                        .font(.spaceMono(9, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white)
                }
                Spacer()
                Button(action: close) {
                    Text("✕")
                        .font(.spaceMono(14))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            (Text("PULSE").foregroundStyle(.white) + Text("+").foregroundStyle(Color(hex: "#F2C14E")))
                .font(.archivo(44, weight: .black))
                .tracking(0.5)
                .padding(.top, 10)
            Text("Train smarter. Track deeper. Share with your crew.")
                .font(.archivo(15))
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(3)
                .frame(maxWidth: 290, alignment: .leading)
                .padding(.top, 10)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pumpAccent, ignoresSafeAreaEdges: .top)
    }

    // MARK: - Next session preview (built from the user's own lifts)

    private struct PredictionRow: Identifiable {
        let id = UUID()
        let name: String
        let delta: String
        let target: String
        let confidence: Int
    }

    private var unit: UnitPreference { users.first?.unitPreference ?? .kg }
    private var unitLabel: String { unit.label }

    private var predictionRows: [PredictionRow] {
        guard let name = predictedName?.lowercased(),
              let last = workouts.first(where: { $0.template?.name.lowercased() == name }) else { return [] }
        let logs = last.exerciseLogs.sorted { $0.order < $1.order }.prefix(3)
        return logs.compactMap { log -> PredictionRow? in
            guard let ex = log.exercise else { return nil }
            let tops = log.workingSets.filter { $0.weight > 0 }
            guard let top = tops.max(by: { $0.weight < $1.weight }) else { return nil }
            // Prior sessions of the same exercise, newest first.
            let history = workouts.compactMap { w in
                w.exerciseLogs.first(where: { $0.exercise?.id == ex.id })?.workingSets.map(\.weight).max()
            }
            var target = top.weight
            if history.count >= 2, history[0] > history[1] { target = history[0] + (history[0] - history[1]) }
            let diff = target - top.weight
            let fmt: (Double) -> String = { unit.number($0) }   // set weights are kg
            let delta = diff > 0 ? "▲ +\(fmt(diff)) \(unitLabel) VS LAST" : "HOLD AT LAST"
            return PredictionRow(name: ex.name, delta: delta,
                                 target: "\(fmt(target))×\(top.reps)",
                                 confidence: min(5, max(1, history.count)))
        }
    }

    private var previewCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("NEXT SESSION · PREVIEW")
                    .font(.archivo(14, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text("PULSE+")
                    .font(.spaceMono(8, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(Color.accentInk)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)

            HStack(spacing: 8) {
                Text(headerLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("TARGET").frame(width: 70, alignment: .trailing)
                Text("CONF").frame(width: 60, alignment: .trailing)
            }
            .font(.spaceMono(8))
            .tracking(1.5)
            .foregroundStyle(Color.inkMuted)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Color.surf2)
            .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

            ForEach(predictionRows) { row in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.name)
                            .font(.archivo(14, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                            .lineLimit(1)
                        Text(row.delta)
                            .font(.spaceMono(8))
                            .tracking(1)
                            .foregroundStyle(Color.signalUp)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.target)
                        .font(.spaceMono(13, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(width: 70, alignment: .trailing)
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { i in
                            Circle().fill(i < row.confidence ? Color.pumpAccent : Color.ruleStrong)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(width: 60, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }

            Text("BUILT FROM YOUR LAST \(workouts.count) WORKOUTS")
                .font(.spaceMono(9))
                .tracking(0.8)
                .foregroundStyle(Color.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        }
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.dsHairLine, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var headerLabel: String {
        let day: String = {
            let f = DateFormatter(); f.dateFormat = "EEE"
            return f.string(from: Date()).uppercased()
        }()
        return "\((predictedName ?? "").uppercased()) · \(day)"
    }

    // MARK: - Spec sheet

    private var specSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SPEC SHEET")
                Spacer()
                Text(String(format: "%02d MODULES", features.count))
            }
            .font(.spaceMono(9))
            .tracking(1.5)
            .foregroundStyle(Color.inkMuted)
            .padding(.horizontal, 16)
            .padding(.top, 22).padding(.bottom, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

            ForEach(Array(features.enumerated()), id: \.offset) { i, f in
                HStack(spacing: 10) {
                    Text(String(format: "%02d", i + 1))
                        .font(.spaceMono(11, weight: .bold))
                        .foregroundStyle(Color.accentInk)
                        .frame(width: 30, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.title)
                            .font(.archivo(14, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        Text(f.sub)
                            .font(.spaceMono(9))
                            .tracking(0.3)
                            .foregroundStyle(Color.inkMuted)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: f.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(width: 18, height: 18)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }
        }
    }

    // MARK: - Active

    private var activeSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIVE · \(activePeriodLabel)")
                    .font(.spaceMono(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.accentInk)
                Text("Thank you for subscribing. Manage in App Store.")
                    .font(.archivo(13))
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer()
        }
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.dsHairLine, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 22)
    }

    private var activePeriodLabel: String {
        switch service.currentSubscription?.subscription?.subscriptionPeriod.unit {
        case .year: "ANNUAL"
        case .month: "MONTHLY"
        default: "PULSE+"
        }
    }

    // MARK: - Trial

    private var trialNote: some View {
        Text("\(service.trialDaysRemaining) DAYS LEFT IN TRIAL")
            .font(.spaceMono(9, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(Color.accentInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 18)
    }

    // MARK: - Plan picker

    private func product(for period: BillingPeriod) -> Product? {
        service.availableProducts.first {
            $0.subscription?.subscriptionPeriod.unit == (period == .annual ? .year : .month)
        }
    }

    private var planSection: some View {
        VStack(spacing: 0) {
            Text("PLAN")
                .font(.spaceMono(9))
                .tracking(1.5)
                .foregroundStyle(Color.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 22).padding(.bottom, 8)
            HStack(spacing: 8) {
                planCard(.monthly)
                planCard(.annual)
            }
            .padding(.horizontal, 16)
        }
    }

    private func planCard(_ period: BillingPeriod) -> some View {
        let active = billingPeriod == period
        let p = product(for: period)
        let monthly = product(for: .monthly)
        let perMonth: String = {
            guard let p else { return "—" }
            if period == .monthly { return p.displayPrice }
            return (p.price / 12).formatted(p.priceFormatStyle)
        }()
        let sub: String = {
            guard let p else { return "" }
            return period == .monthly
                ? "\((p.price * 12).formatted(p.priceFormatStyle)) / YR"
                : "\(p.displayPrice) / YR"
        }()
        let saving: Int? = {
            guard period == .annual, let p, let monthly, monthly.price > 0 else { return nil }
            let pct = (1 - (p.price / 12) / monthly.price) * 100
            return Int((NSDecimalNumber(decimal: pct).doubleValue).rounded())
        }()
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { billingPeriod = period }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(period == .annual ? "ANNUAL" : "MONTHLY")
                        .font(.spaceMono(8, weight: active ? .bold : .regular))
                        .tracking(1.5)
                        .foregroundStyle(active ? Color.accentInk : Color.inkMuted)
                    Spacer()
                    if let saving, saving > 0 {
                        Text("▼ \(saving)%")
                            .font(.spaceMono(8, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Color.signalUp)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(perMonth)
                        .font(.spaceMono(24, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("/MO")
                        .font(.spaceMono(8))
                        .tracking(1)
                        .foregroundStyle(Color.inkMuted)
                }
                .padding(.top, 10)
                Text(sub)
                    .font(.spaceMono(8))
                    .tracking(1)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.top, 8)
            }
            .padding(active ? 11 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(active ? Color.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(active ? Color.pumpAccent : Color.ruleStrong, lineWidth: active ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA dock

    private var ctaDock: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.dsHairLine).frame(height: 1)
            VStack(spacing: 8) {
                if service.isLoading {
                    ProgressView().frame(height: 54)
                } else if let product = matchedProduct {
                    Button {
                        Task { await purchaseProduct(product) }
                    } label: {
                        HStack {
                            Text("START PULSE+")
                                .font(.archivo(15, weight: .black))
                                .tracking(0.5)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(product.displayPrice)
                                    .font(.spaceMono(11, weight: .bold))
                                Text(billingPeriod == .annual ? "PER YEAR" : "PER MONTH")
                                    .font(.spaceMono(8))
                                    .tracking(1)
                                    .opacity(0.85)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.pumpAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))
                } else {
                    Text("Subscriptions unavailable")
                        .font(.spaceMono(11))
                        .foregroundStyle(Color.inkMuted)
                        .frame(height: 54)
                }
                Text("Cancel anytime in App Store settings.")
                    .font(.spaceMono(9))
                    .tracking(0.5)
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .background(Color.canvasBg)
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
                .frame(maxWidth: .infinity)
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
