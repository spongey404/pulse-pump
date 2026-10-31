import SwiftUI
import SwiftData

/// The Supernova membership page (design "Supernova Member Flow"): a full-page glitter in the member's accent, fixed behind the
/// scroll view and masked so it covers the top 65 % and fades to charcoal; white text on glass; sticky OVERVIEW · PERKS · ACCOUNT
/// tabs. It grows out of the More card (`SupernovaTransition`, kind `.member`): its four content groups (header row, wordmark,
/// card, tabs and content) arrive staggered, and its wordmark's "*" is where the flyer lands.
struct SupernovaMemberPage: View {
    var onBack: () -> Void

    @Environment(\.paywallReveal) private var reveal
    @Query private var users: [User]
    @Query(filter: #Predicate<Workout> { !$0.isDraft && $0.deletedAt == nil }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @State private var service = SupernovaService()
    @State private var transition = SupernovaTransition.shared
    @State private var tab: Int = {
        #if DEBUG
        return Int(UserDefaults.standard.string(forKey: "debugMemberTab") ?? "") ?? 0   // `-debugMemberTab 0|1|2`
        #else
        return 0
        #endif
    }()
    @State private var anchor: CGRect?
    /// How far the scroll view has moved up; the glitter travels with the content and leaves plain charcoal behind.
    @State private var scrolled: CGFloat = 0
    private var config: SupernovaMemberConfig { SupernovaMemberConfigStore.shared.current }
    private var palette: StarPalette { AccentStore.shared.pickedPalette }
    private var user: User? { users.first }

    @Environment(\.colorScheme) private var scheme
    /// The page's text, rules and surfaces follow the appearance (charcoal and white, or paper and ink); what sits on the glitter
    /// (header, wordmark, glass card) is white in both.
    private var t: MemberPageTheme { MemberPageTheme(dark: scheme == .dark) }

    var body: some View {
        ZStack(alignment: .top) {
            t.canvas.ignoresSafeArea()
            StarFieldView(variant: "paywall", budget: .paywall,
                          overrides: StarFieldParams.Overrides(palette: palette, density: config.page.count, speed: config.page.speed,
                                                               gold: config.page.gold, sparkle: config.page.sparkle, goldPull: config.page.pull),
                          anchor: anchor)
                .ignoresSafeArea()
                .mask(LinearGradient(stops: config.page.maskStops.map { .init(color: .black.opacity($0[1]), location: $0[0]) },
                                     startPoint: .top, endPoint: .bottom).ignoresSafeArea())
                .offset(y: -scrolled)
                .allowsHitTesting(false)
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    VStack(alignment: .leading, spacing: 0) {
                        header.paywallGroup(0, reveal)
                        wordmark.paywallGroup(1, reveal)
                        card.paywallGroup(2, reveal)
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)
                    .background(GeometryReader { g in
                        Color.clear.onChange(of: g.frame(in: .named("memberScroll")).minY) { _, y in scrolled = max(0, -y) }
                    })
                    Section {
                        Group {
                            switch tab {
                            case 0: overview
                            case 1: perks
                            default: account
                            }
                        }
                        .paywallGroup(3, reveal)
                    } header: {
                        tabs.paywallGroup(3, reveal)
                    }
                }
            }
            .coordinateSpace(name: "memberScroll")
        }
        .foregroundStyle(t.ink)
        .onPreferenceChange(SupernovaAsteriskFrameKey.self) {
            anchor = $0
            if let f = $0 { transition.wordmarkMeasured(f) }
        }
        .task {
            service.startListening()
            await service.loadProducts()
            await service.refreshSubscriptionStatus()
        }
        .onDisappear { service.stopListening(); AccentStore.shared.commitColour() }   // the colour joins the recent row when the page closes
        .accessibilityIdentifier(AX.supernova.memberPage)
    }

    // MARK: Header, wordmark, card

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: { if transition.acceptsInput { AccentStore.shared.commitColour(); onBack() } }) {
                Text("‹").font(.archivo(24)).frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, -14)
            .accessibilityLabel("Back")
            .accessibilityIdentifier(AX.supernova.memberBack)
            Rectangle().fill(.white).frame(width: 12, height: 12)
            Text("\(Brand.appName.uppercased()) · \(Brand.membershipName.uppercased()) MEMBER")
                .font(.spaceMono(10, weight: .bold)).tracking(2)
        }
        .padding(.top, 4)
    }

    private var wordmark: some View {
        SupernovaWordmark(size: 44, tracking: -0.5, gapEm: SupernovaAsterisk.paywallGapEm, asteriskHidden: transition.wordmarkAsteriskHidden)
            .frame(height: 44 * 0.95, alignment: .bottom)
            .padding(.top, 16.6)   // 14 in the design; measured: the glyphs sit 2.6 pt lower in a CSS 0.95 line box
    }

    private var card: some View {
        let name = user?.name ?? "Athlete"
        let handle = (user?.username.isEmpty == false ? user!.username : name).lowercased().replacingOccurrences(of: " ", with: "")
        return VStack(alignment: .leading, spacing: config.card.gap) {
            HStack(alignment: .top) {
                Text("MEMBER · \(service.planWord)").font(.spaceMono(9, weight: .bold)).tracking(2).foregroundStyle(.white.opacity(0.92))
                Spacer(minLength: 0)
                Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                    .font(.archivo(20, weight: .black))
                    .frame(width: 44, height: 44).background(.white.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(name).font(.archivo(22, weight: .bold)).lineLimit(1).cssLineHeight(fontName: "Archivo-Bold", size: 22, multiple: 1.1)
                Text("@\(handle.uppercased())").font(.spaceMono(10)).tracking(1.5).foregroundStyle(.white.opacity(0.92)).padding(.top, 6)
            }
            HStack(alignment: .bottom, spacing: 10) {
                HStack(alignment: .top, spacing: 18) {
                    column("MEMBER SINCE", service.memberSinceShort)
                    column("RENEWS", service.renewsShort)
                }
                Spacer(minLength: 0)
                column("PLAN", service.planPriceLabel ?? "—", trailing: true)
            }
        }
        .padding(.horizontal, config.card.padH).padding(.vertical, config.card.padV)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial.opacity(0.6)).environment(\.colorScheme, .dark)
                LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: config.card.radius))
        .overlay(RoundedRectangle(cornerRadius: config.card.radius).strokeBorder(.white.opacity(0.38), lineWidth: 1))
        .padding(.top, 16.4)   // 18 in the design, less what the wordmark gave
    }

    private func column(_ label: String, _ value: String, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 3) {
            Text(label).font(.spaceMono(7)).tracking(1.5).foregroundStyle(.white.opacity(0.8))
            Text(value).font(.spaceMono(12, weight: .bold))
        }
    }

    // MARK: Tabs

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(Array(["OVERVIEW", "PERKS", "ACCOUNT"].enumerated()), id: \.offset) { i, label in
                Button { tab = i } label: {
                    Text(label).font(.spaceMono(9, weight: .bold)).tracking(1.5)
                        .foregroundStyle(i == tab ? Color(hex: "#151A21") : (t.dark ? .white.opacity(0.8) : .white))
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background(i == tab ? (t.dark ? Color.white.opacity(0.92) : Color.white) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AX.supernova.memberTab(label))
                .accessibilityAddTraits(i == tab ? .isSelected : [])
            }
        }
        .padding(3)
        .background(t.chip)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background {
            // No blur and no band: the page glitter stays sharp behind the pinned tabs, with no hard edge.
            Color.clear
        }
    }

    private func sectionLabel(_ left: String, _ right: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(left); Spacer(minLength: 0); Text(right)
        }
        .font(.spaceMono(9)).tracking(1.5).foregroundStyle(t.muted)
        .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 8)
    }

    // MARK: Overview

    private var impact: (suggested: Int, prs: Int, lagging: Int, recaps: Int) {
        let since = service.memberSince ?? Date()
        let cal = WeeklyRecapStats.isoMonday
        let from = cal.date(byAdding: .day, value: -28, to: Date()) ?? Date()
        let recent = workouts.filter { $0.date >= from }
        let sets = WeeklyRecapStats(workouts: recent, unit: user?.unitPreference ?? .kg).muscleSets(recent)
        return (SupernovaImpact.suggestedWeightsUsed(), SupernovaImpact.prsOnSuggestedWeight(),
                SupernovaImpact.laggingMuscles(setsByGroup: sets),
                SupernovaImpact.weeklyRecapsSent(since: since, workoutDates: workouts.map(\.date)))
    }

    private var overview: some View {
        let i = impact
        let cells: [(String, String)] = [(SupernovaOverview.cell(i.suggested), "SUGGESTED WEIGHTS USED"), (SupernovaOverview.cell(i.prs), "PRS ON A SUGGESTED WEIGHT"),
                                         (SupernovaOverview.cell(i.lagging), "LAGGING MUSCLES FLAGGED"), (SupernovaOverview.cell(i.recaps), "WEEKLY RECAPS SENT")]
        let headline = SupernovaOverview.headline(prs: i.prs, suggested: i.suggested, recaps: i.recaps)
        let showsStats = SupernovaOverview.showsStats(prs: i.prs, suggested: i.suggested, lagging: i.lagging, recaps: i.recaps)
        return VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if let headline {
                    Text("\(headline.number)").font(.spaceMono(48, weight: .bold)).frame(height: 48 * 0.9)   // a CSS 0.9 line box: the glyphs overflow it, so no exact line height (it would clip them)
                    Text(headline.text).font(.archivo(15, weight: .semibold))
                        .cssLineHeight(fontName: "Archivo-SemiBold", size: 15, multiple: 1.3)
                        .fixedSize(horizontal: false, vertical: true).frame(width: 200, alignment: .leading)
                } else {
                    Text(SupernovaOverview.emptyHeadline).font(.archivo(15, weight: .semibold))
                        .cssLineHeight(fontName: "Archivo-SemiBold", size: 15, multiple: 1.3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(AX.supernova.memberEmptyHeadline)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 4)
            if showsStats {
                sectionLabel("WHAT SUPERNOVA DID FOR YOU", "SINCE \(service.memberSinceMonth)")
                Rectangle().fill(t.rule1).frame(height: 1)
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(0..<2, id: \.self) { row in
                        GridRow {
                            ForEach(0..<2, id: \.self) { col in
                                let c = cells[row * 2 + col]
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(c.0).font(.spaceMono(26, weight: .bold)).frame(height: 26)   // line-height 1
                                    Text(c.1).font(.spaceMono(8)).tracking(1.2).foregroundStyle(t.muted)
                                        .cssLineHeight(fontName: "SpaceMono-Regular", size: 8, multiple: 1.4)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                                .padding(.bottom, 1)   // the cell's 1 pt bottom border takes space in CSS
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .overlay(alignment: .bottom) { Rectangle().fill(t.rule1).frame(height: 1) }
                                .overlay(alignment: .leading) { if col == 1 { Rectangle().fill(t.rule1).frame(width: 1) } }
                            }
                        }
                    }
                }
            }
            sectionLabel("INCLUDED APPS", "3")
            HStack(alignment: .top, spacing: 8) {
                appTile(Brand.appName, "LIFTING", status: "ACTIVE", active: true, url: nil)
                appTile(Brand.tareName, "CALORIES", status: "INCLUDED · GET ›", active: false, url: Brand.tareStoreURL)
                appTile(Brand.driftName, "STEPS", status: "INCLUDED · GET ›", active: false, url: Brand.driftStoreURL)
            }
            .padding(.horizontal, 16)
            Color.clear.frame(height: 40)
        }
    }

    private func appTile(_ name: String, _ detail: String, status: String, active: Bool, url: URL?) -> some View {
        let tile = VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 7)
                .fill(active ? Color(hex: AccentStore.shared.picked.hexString) : .clear)
                .overlay { if !active { RoundedRectangle(cornerRadius: 7).strokeBorder(t.rule2, lineWidth: 1.5) } }
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.archivo(16, weight: .bold))
                Text(detail).font(.spaceMono(8)).tracking(1.5).foregroundStyle(t.muted)
            }
            Text(status).font(.spaceMono(8, weight: .bold)).tracking(1.5)
                .foregroundStyle(active ? (t.dark ? Color.white : Color(hex: "#151A21")) : t.secondary).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(t.rule1, lineWidth: 1))
        return Group {
            if let url { Link(destination: url) { tile }.buttonStyle(.plain) } else { tile }
        }
    }

    // MARK: Perks

    private static let perks: [(name: String, how: String)] = [
        ("Smart weight suggestions", "Shown on every set in the logger. Hit the rep target and the next weight goes up."),
        ("Muscle balance", "Body tab, then Balance. Groups behind the rest are marked ▼."),
        ("Detailed analytics", "Open any exercise, then Trends. 1RM, volume and deload weeks."),
        ("Weekly Recap", "Arrives Sunday evening. Training, food and steps in one card."),
        ("Cloud Sync", "On automatically. Your workouts are on every device you sign in on."),
    ]

    private var perks: some View {
        VStack(spacing: 0) {
            sectionLabel("YOUR PERKS", "\(Self.perks.count)")
            Rectangle().fill(t.rule1).frame(height: 1)
            ForEach(Array(Self.perks.enumerated()), id: \.offset) { i, p in
                HStack(alignment: .top, spacing: 12) {
                    StarBullet(size: config.page.starBullet, delay: -(Double(i) * config.page.perkOffset).truncatingRemainder(dividingBy: SignupConfigStore.shared.current.bullet.seconds))
                        .frame(width: 16).padding(.top, 3)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.name).font(.archivo(15, weight: .semibold))
                        Text(p.how).font(.archivo(13)).foregroundStyle(t.secondary)
                            .cssLineHeight(fontName: "Archivo-Regular", size: 13, multiple: 1.4).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .padding(.bottom, 1)
                .overlay(alignment: .bottom) { Rectangle().fill(t.rule1).frame(height: 1) }
            }
            Color.clear.frame(height: 40)
        }
    }

    // MARK: Account

    private var account: some View {
        VStack(spacing: 0) {
            sectionLabel("ACCENT", "RECOLOURS YOUR CARD")
            AccentPickerView(theme: t)
            sectionLabel("MEMBERSHIP", "")
            Rectangle().fill(t.rule1).frame(height: 1)
            let plan = service.planPriceLabel.map { service.planWord + " · " + $0.replacingOccurrences(of: " / YR", with: "").replacingOccurrences(of: " / MO", with: "") } ?? service.planWord
            row("Plan", plan)
            row("Renews", service.renewsLong)
            row("Member since", service.memberSinceLong)
            Button { Task { await service.showManageSubscriptions() } } label: { rowLabel("Manage subscription", "APP STORE") }
                .buttonStyle(.plain).accessibilityIdentifier(AX.supernova.manageSubscription)
            HStack {
                Button { Task { await service.restorePurchases() } } label: {
                    Text("RESTORE PURCHASES").font(.spaceMono(9)).tracking(1.5).foregroundStyle(t.muted).padding(.vertical, 12)
                }
                .buttonStyle(.plain).accessibilityIdentifier(AX.supernova.restore)
                Spacer()
                Button { Task { await service.showManageSubscriptions() } } label: {
                    Text("CANCEL MEMBERSHIP").font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color(hex: "#FF8A7A")).padding(.vertical, 12)
                }
                .buttonStyle(.plain).accessibilityIdentifier(AX.supernova.cancelMembership)
            }
            .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 34)
        }
    }

    private func row(_ label: String, _ value: String) -> some View { rowLabel(label, value) }

    private func rowLabel(_ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.archivo(15, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading)
            Text(value).font(.spaceMono(10)).tracking(0.8).foregroundStyle(t.muted)
            Text("›").font(.spaceMono(16)).foregroundStyle(t.ghost)
        }
        .frame(minHeight: 48).padding(.horizontal, 16).padding(.bottom, 1)
        .overlay(alignment: .bottom) { Rectangle().fill(t.rule1).frame(height: 1) }
        .contentShape(Rectangle())
    }
}
