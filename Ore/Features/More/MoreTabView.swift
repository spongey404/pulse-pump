import SwiftUI
import SwiftData

// MARK: - More Tab  (matches More Hub.dc.html / More Screens.dc.html)

struct MoreTabView: View {
    @Bindable var tutorialViewModel: TutorialViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthSession.self) private var session
    @Query private var users: [User]
    @Query(filter: #Predicate<Workout> { !$0.isDraft && $0.deletedAt == nil }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    #if DEBUG
    // `-debugMoreScreen <name>` launch argument opens a sub-screen for visual checks.
    @State private var screen: MoreScreen = MoreScreen.debugInitial
    #else
    @State private var screen: MoreScreen = .hub
    #endif
    @State private var showSignOutAlert = false
    #if DEBUG
    @State private var showStarFieldPanel = false
    #endif
    @State private var showTutorialDraftAlert = false
    @Query(filter: #Predicate<Workout> { $0.isDraft && $0.deletedAt == nil }) private var drafts: [Workout]
    @State private var supernovaService = SupernovaService()
    @State private var social = SocialViewModel.shared

    private var user: User? { users.first }
    private var streak: Int { StreakCalculator.currentStreak(from: workouts.map(\.date)) }

    var body: some View {
        Group {
            switch screen {
            case .hub:      hubView
            case .history:  WorkoutHistoryView(onBack: { screen = .hub })
            case .profile:  ProfileView(onBack: { screen = .hub })
            case .settings: SettingsView(onBack: { screen = .hub })
            case .equipment: EquipmentProfilesView(onBack: { screen = .hub })
            case .supernova: hubView
            case .weeklyRecap: WeeklyRecapView(onBack: { screen = .hub })
            case .dataImport: DataImportScreen(onBack: { screen = .hub })
            case .privacy:   PrivacyLegalView(onBack: { screen = .hub })
            case .widgets:   WidgetsView(onBack: { screen = .hub })
            }
        }
        .animation(.easeInOut(duration: 0.22), value: screen)
        .onAppear {
            consumeRouter()
            #if DEBUG
            SupernovaTransition.shared.runDebugRequest()
            #endif
        }
        .onChange(of: MoreRouter.shared.pendingSupernova) { _, _ in consumeRouter() }
        // Both Supernova pages are `SupernovaTransitionHost`'s (the free paywall grows out of the banner, the members' page out
        // of their membership card); any other way in (a row, a locked widget's link) lands on the right one too.
        .onChange(of: screen) { _, new in
            guard new == .supernova else { return }
            screen = .hub
            SupernovaTransition.shared.open(isFree ? .paywall : .member, fromSource: false)
        }
        #if DEBUG
        .sheet(isPresented: $showStarFieldPanel) { StarFieldDevPanel() }
        #endif
    }

    private func consumeRouter() {
        if MoreRouter.shared.pendingSupernova {
            MoreRouter.shared.pendingSupernova = false
            screen = .supernova
        }
    }

    // MARK: - Hub  (More Hub.dc.html · 3a "Combined hub")

    private var isFree: Bool { !supernovaService.isSubscribed }

    private var hubView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("MORE")
                    .font(.archivo(28, weight: .black))
                    .tracking(0.5)
                    .foregroundStyle(Color.inkPrimary)
                    .cssLineHeight(fontName: "Archivo-Black", size: 28, multiple: 1.0)
                    .accessibilityIdentifier(AX.more.screen)
                    #if DEBUG
                    .onLongPressGesture(minimumDuration: 1.0) { showStarFieldPanel = true }   // hidden glitter tuning panel
                    #endif
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                if isFree { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if isFree {
                        userHeader
                        statsRow
                        SupernovaBanner()
                    } else {
                        // Members: the membership card takes the profile row's place; no glitter anywhere else.
                        SupernovaMemberCard(name: user?.name ?? "Athlete", username: memberHandle, program: memberProgram, service: supernovaService)
                        statsRow
                    }

                    MoreSectionLabel(title: "TRAINING", top: 16, bottom: 6)
                    MoreRow(icon: "clock.arrow.circlepath", label: "History",
                            value: "\(workouts.count)", minHeight: 48) { screen = .history }
                    MoreRow(icon: "dumbbell", label: "Equipment Profiles",
                            value: activeEquipmentName, minHeight: 48) { screen = .equipment }
                    MoreRow(icon: "waveform.path.ecg", label: "Weekly Recap",
                            value: "WK \(weekNumber)", minHeight: 48) { screen = .weeklyRecap }
                    MoreRow(icon: "square.grid.2x2", label: "Widgets", minHeight: 48, tag: "SUPERNOVA") {
                        screen = supernovaService.isSubscribed || supernovaService.isInFreeTrial ? .widgets : .supernova
                    }

                    MoreSectionLabel(title: "ACCOUNT", top: 16, bottom: 6)
                    MoreRow(icon: "gearshape", label: "Settings", minHeight: 48) { screen = .settings }
                    if isFree {
                        MoreRow(icon: "bolt", label: Brand.membershipName, value: "FREE", minHeight: 48) { screen = .supernova }
                            .accessibilityIdentifier(AX.row(Brand.membershipName))
                    }

                    MoreSectionLabel(title: "HELP", top: 16, bottom: 6)
                    MoreRow(icon: "questionmark.circle", label: "Tutorial", minHeight: 48) {
                        // The tutorial runs a practice workout, so it can't start over a real one.
                        if drafts.isEmpty { tutorialViewModel.start() } else { showTutorialDraftAlert = true }
                    }
                    MoreRow(icon: "square.and.arrow.down", label: "Data Import",
                            value: "STRONG · HEVY", minHeight: 48) { screen = .dataImport }
                    MoreRow(icon: "shield", label: "Privacy & Legal", minHeight: 48) { screen = .privacy }
                    MoreRow(icon: "rectangle.portrait.and.arrow.right", label: "Sign Out",
                            destructive: true, chevron: false, minHeight: 48) { showSignOutAlert = true }

                    Spacer().frame(height: 32)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .alert("Finish your workout first", isPresented: $showTutorialDraftAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The tutorial uses a practice workout. Finish or discard your current one, then replay it.")
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task { await session.signOut() }
            }
        } message: {
            Text("This removes your data from this device. It stays safe in your account and comes back when you sign in.")
        }
        .task {
            await supernovaService.refreshSubscriptionStatus()
            SocialServices.localName = user?.name
            await social.loadMyProfile()
            await social.loadGraph()
            await social.syncOwnStats(streak: streak, totalWorkouts: workouts.count)
        }
    }

    private var activeEquipmentName: String {
        let profiles = user?.liveEquipmentProfiles ?? []
        return (profiles.first?.name ?? "").uppercased()
    }

    private var weekNumber: Int {
        Calendar.current.component(.weekOfYear, from: Date())
    }

    // MARK: - User header + stat row

    private var userHeader: some View {
        Button { screen = .profile } label: {
            HStack(spacing: 14) {
                Avatar(initial: user?.name ?? "?", size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(user?.name ?? "Athlete")
                        .font(.archivo(20, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                    Text(handleLine)
                        .font(.spaceMono(9))
                        .tracking(0.8)
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
                Text("›").font(.spaceMono(16)).foregroundStyle(Color.inkGhost)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var memberHandle: String {
        let raw = (user?.username.isEmpty == false ? user?.username : user?.name) ?? "athlete"
        return raw.lowercased().replacingOccurrences(of: " ", with: "")
    }
    private var memberProgram: String {
        guard let split = user?.selectedSplit?.name, !split.isEmpty else { return "" }
        return Self.shortSplit(split)
    }

    private var handleLine: String {
        let raw = (user?.username.isEmpty == false ? user?.username : user?.name) ?? "athlete"
        var parts = ["@" + raw.lowercased().replacingOccurrences(of: " ", with: "")]
        if let split = user?.selectedSplit?.name, !split.isEmpty { parts.append(isFree ? split.uppercased() : Self.shortSplit(split)) }
        return parts.joined(separator: " · ")
    }

    /// "Push Pull Legs" → "PPL" beside a member's tag (the design's "@alexmercer · PPL"); other names stay whole.
    static func shortSplit(_ name: String) -> String {
        switch name.lowercased() {
        case "push pull legs", "ppl": "PPL"
        case "upper lower", "upper/lower": "U/L"
        default: name.uppercased()
        }
    }

    private var statsRow: some View {
        let stats: [(String, String)] = [
            ("\(workouts.count)", "WORKOUTS"),
            ("\(streak)D", "STREAK"),
            ("\(social.friendCount)", "FRIENDS"),
            ("\(social.fanCount)", "FANS"),
        ]
        return HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.offset) { i, k in
                VStack(spacing: 5) {
                    Text(k.0).font(.spaceMono(18, weight: .bold)).foregroundStyle(Color.inkPrimary)
                    Text(k.1).font(.spaceMono(7)).tracking(1.2).foregroundStyle(Color.inkMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12).padding(.bottom, 11)
                .overlay(alignment: .leading) {
                    if i > 0 { Rectangle().fill(Color.dsHairLine).frame(width: 1) }
                }
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

}

/// Lets deep links (e.g. a locked widget) ask the More tab to open Supernova even before it has appeared.
@Observable
final class MoreRouter {
    static let shared = MoreRouter()
    var pendingSupernova = false
}

// MARK: - Screen enum

private enum MoreScreen {
    case hub, history, profile, settings, equipment, supernova, weeklyRecap, dataImport, privacy, widgets
}

#if DEBUG
private extension MoreScreen {
    static var debugInitial: MoreScreen {
        switch UserDefaults.standard.string(forKey: "debugMoreScreen") {
        case "history": .history
        case "profile": .profile
        case "settings": .settings
        case "equipment": .equipment
        case "supernova": .supernova
        case "weeklyRecap": .weeklyRecap
        case "dataImport": .dataImport
        case "privacy": .privacy
        case "widgets": .widgets
        default: .hub
        }
    }
}
#endif
