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
    @State private var showSignOut = false
    #if DEBUG
    @State private var showStardustPanel = false
    #endif
    @State private var showTutorialDraftAlert = false
    @Query(filter: #Predicate<Workout> { $0.isDraft && $0.deletedAt == nil }) private var drafts: [Workout]
    @State private var supernovaService = SupernovaService()
    @State private var social = SocialViewModel.shared

    private var user: User? { users.first }
    /// Weeks in a row with a workout: the same number Home and its ticker show.
    private var weekStreak: Int { HomeWeekStats(workouts: workouts, templates: []).weekStreak }

    var body: some View {
        ZStack {
            OrePushStack(isOpen: pageOpen) {
                hubView
            } page: {
                page
            }
            .blur(radius: showSignOut ? 3 : 0)   // the scrim's 6 pt backdrop blur (CSS px are twice SwiftUI's radius)
            signOutSheet
                .zIndex(2)
        }
        .animation(OrePushStack<EmptyView, EmptyView>.animation, value: showSignOut)
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
        .sheet(isPresented: $showStardustPanel) { StardustDevPanel() }
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

    private var pageOpen: Bool { screen != .hub && screen != .supernova }

    @ViewBuilder private var page: some View {
        switch screen {
        case .history:  WorkoutHistoryView(onBack: { screen = .hub })
        case .analytics: AnalyticsView(onBack: { screen = .hub })
        case .profile:  ProfileView(onBack: { screen = .hub })
        case .settings: SettingsView(onBack: { screen = .hub })
        case .equipment: EquipmentProfilesView(onBack: { screen = .hub })
        case .weeklyRecap: WeeklyRecapView(onBack: { screen = .hub })
        case .cloudSync: CloudSyncView(isMember: !isFree, onBack: { screen = .hub })
        case .dataImport: DataImportScreen(onBack: { screen = .hub })
        case .privacy:   PrivacyLegalView(onBack: { screen = .hub })
        case .widgets:   WidgetsView(onBack: { screen = .hub })
        case .hub, .supernova: EmptyView()
        }
    }

    private var syncedText: String {
        guard let date = SyncService.shared.lastSyncedAt else { return "Not synced yet" }
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .short
        return "Synced " + f.localizedString(for: date, relativeTo: Date())
    }

    /// SIGN OUT: a bottom sheet over a scrim (rgba(21,26,33,0.45) + 6 pt blur); it slides up over 350 ms.
    private var signOutSheet: some View {
        ZStack(alignment: .bottom) {
            if showSignOut {
                Color(red: 21 / 255, green: 26 / 255, blue: 33 / 255).opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { showSignOut = false }
                    .transition(.opacity)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text("SIGN OUT").font(.archivo(22, weight: .black)).foregroundStyle(Color.inkPrimary)
                    Text("You'll need to sign back in to access your data.")
                        .font(.archivo(13)).foregroundStyle(Color.inkSecondary)
                        .cssLineHeight(fontName: "Archivo-Regular", size: 13, multiple: 1.45)
                        .padding(.bottom, 12)
                    Button { showSignOut = false } label: {
                        Text("CANCEL").font(.archivo(14, weight: .black)).tracking(1).foregroundStyle(Color.inkPrimary)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(Color.surf2).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain).accessibilityIdentifier(AX.more.signOutCancel)
                    Button {
                        showSignOut = false
                        Task { await session.signOut() }
                    } label: {
                        Text("SIGN OUT").font(.archivo(14, weight: .black)).tracking(1).foregroundStyle(Color.signalDown)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(Color.signalDown.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain).accessibilityIdentifier(AX.more.signOutConfirm)
                }
                .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 34)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surf.ignoresSafeArea(edges: .bottom))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14, style: .continuous))
                .transition(.move(edge: .bottom))
            }
        }
    }

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
                    .onLongPressGesture(minimumDuration: 1.0) { showStardustPanel = true }   // hidden Stardust tuning panel
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
                        // Members: the membership card takes the profile row's place; no Stardust anywhere else.
                        SupernovaMemberCard(name: user?.name ?? "Athlete", username: memberHandle, program: memberProgram, service: supernovaService)
                        statsRow
                    }

                    MoreSectionLabel(title: "TRAINING")
                    MoreRow(label: "History", description: "Every workout you have logged. \(workouts.count) so far.") { screen = .history }
                    MoreRow(label: "Analytics", description: "1RM, volume and trends for each exercise.") { screen = .analytics }
                    MoreRow(label: "Equipment profiles", description: "Plates and bars at each gym." + (activeEquipmentName.isEmpty ? "" : " Using \(activeEquipmentName).")) { screen = .equipment }
                    MoreRow(label: "Weekly Recap", description: "Training, food and steps for the week. Every Sunday.") { screen = .weeklyRecap }

                    MoreSectionLabel(title: "ACCOUNT")
                    MoreRow(label: "Settings", description: "Units, rest timer, theme and notifications.") { screen = .settings }
                    MoreRow(label: "Cloud Sync", description: "Backs up your data automatically. \(syncedText).") { screen = .cloudSync }

                    MoreSectionLabel(title: "HELP")
                    MoreRow(label: "Tutorial", description: "Replays the walkthrough of logging a workout.", chevron: false) {
                        // The tutorial runs a practice workout, so it can't start over a real one.
                        if drafts.isEmpty { tutorialViewModel.start() } else { showTutorialDraftAlert = true }
                    }
                    MoreRow(label: "Data import", description: "Bring your history in from Strong, Hevy or a CSV.") { screen = .dataImport }
                    MoreRow(label: "Privacy & legal", description: "Privacy policy, terms and your data.") { screen = .privacy }
                    MoreRow(label: "Sign out", destructive: true, chevron: false) { showSignOut = true }

                    PreviewMembershipToggle(isMember: supernovaService.isSubscribed) {
                        Task { await supernovaService.refreshSubscriptionStatus() }
                    }
                    Spacer().frame(height: 32)
                }
            }
            // What the list shows (the card or banner may be scrolled partly out of it): the Supernova transition grows from, and
            // shrinks back to, only that part.
            .background(GeometryReader { p in
                Color.clear.onChange(of: p.frame(in: .global), initial: true) { _, f in SupernovaTransition.shared.reportViewport(f) }
            })
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .alert("Finish your workout first", isPresented: $showTutorialDraftAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The tutorial uses a practice workout. Finish or discard your current one, then replay it.")
        }
        .task {
            await supernovaService.refreshSubscriptionStatus()
            SocialServices.localName = user?.name
            await social.loadMyProfile()
            await social.loadGraph()
            await social.syncOwnStats(streak: weekStreak, totalWorkouts: workouts.count)
        }
    }

    private var activeEquipmentName: String {
        let profiles = user?.liveEquipmentProfiles ?? []
        return profiles.sorted { $0.name < $1.name }.first?.name ?? ""   // the Equipment page marks the first by name ACTIVE
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
        .accessibilityIdentifier(AX.more.profile)
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
            ("\(weekStreak) WK", "STREAK"),
            ("\(social.friendCount)", "FRIENDS"),
            ("\(social.fanCount)", "FOLLOWERS"),
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
    case hub, history, analytics, profile, settings, equipment, supernova, weeklyRecap, cloudSync, dataImport, privacy, widgets
}

#if DEBUG
private extension MoreScreen {
    static var debugInitial: MoreScreen {
        switch UserDefaults.standard.string(forKey: "debugMoreScreen") {
        case "history": .history
        case "analytics": .analytics
        case "cloudSync": .cloudSync
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
