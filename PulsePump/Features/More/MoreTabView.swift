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
    @State private var pulsePlusService = PulsePlusService()
    @State private var social = SocialViewModel()

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
            case .pulsePlus: hubView
            case .weeklyRecap: WeeklyRecapView(onBack: { screen = .hub })
            case .dataImport: DataImportScreen(onBack: { screen = .hub })
            case .privacy:   PrivacyLegalView(onBack: { screen = .hub })
            case .widgets:   WidgetsView(onBack: { screen = .hub })
            }
        }
        .animation(.easeInOut(duration: 0.22), value: screen)
        .onAppear { syncTutorialScreen(); consumeRouter() }
        .onChange(of: MoreRouter.shared.pendingPulsePlus) { _, _ in consumeRouter() }
        .onChange(of: tutorialViewModel.currentStep) { _, _ in syncTutorialScreen() }
        .onChange(of: tutorialViewModel.isActive) { _, _ in syncTutorialScreen() }
        // Pulse+ is presented full-screen over the tab bar and closed with its ✕.
        .fullScreenCover(isPresented: Binding(
            get: { screen == .pulsePlus },
            set: { if !$0 { screen = .hub } }
        )) {
            PulsePlusView(onBack: { screen = .hub })
        }
    }

    private func consumeRouter() {
        if MoreRouter.shared.pendingPulsePlus {
            MoreRouter.shared.pendingPulsePlus = false
            screen = .pulsePlus
        }
    }

    /// While the tutorial runs, the More tab shows the screen the current step points at.
    private func syncTutorialScreen() {
        guard tutorialViewModel.isActive, tutorialViewModel.currentStep.requiredTab == 4 else { return }
        switch tutorialViewModel.currentStep.moreScreen {
        case "equipment": screen = .equipment
        case "settings": screen = .settings
        default: screen = .hub
        }
    }

    // MARK: - Hub  (More Hub.dc.html · 3a "Combined hub")

    private var isFree: Bool { !pulsePlusService.isSubscribed }

    private var hubView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("MORE")
                    .font(.archivo(28, weight: .black))
                    .tracking(0.5)
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                Rectangle().fill(Color.dsHairLine).frame(height: 1)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    userHeader
                    statsRow
                    if isFree { plusBanner }

                    MoreSectionLabel(title: "TRAINING", top: 16, bottom: 6)
                    MoreRow(icon: "clock.arrow.circlepath", label: "History",
                            value: "\(workouts.count)", minHeight: 48) { screen = .history }
                    MoreRow(icon: "dumbbell", label: "Equipment Profiles",
                            value: activeEquipmentName, minHeight: 48) { screen = .equipment }
                    MoreRow(icon: "waveform.path.ecg", label: "Weekly Recap",
                            value: "WK \(weekNumber)", minHeight: 48) { screen = .weeklyRecap }
                    MoreRow(icon: "square.grid.2x2", label: "Widgets", minHeight: 48, tag: "PULSE+") {
                        screen = pulsePlusService.isSubscribed || pulsePlusService.isInFreeTrial ? .widgets : .pulsePlus
                    }

                    MoreSectionLabel(title: "ACCOUNT", top: 16, bottom: 6)
                    MoreRow(icon: "gearshape", label: "Settings", minHeight: 48) { screen = .settings }
                    MoreRow(icon: "bolt", label: "Pulse+", value: isFree ? "FREE" : "ACTIVE",
                            minHeight: 48) { screen = .pulsePlus }

                    MoreSectionLabel(title: "HELP", top: 16, bottom: 6)
                    MoreRow(icon: "questionmark.circle", label: "Tutorial", minHeight: 48) {
                        tutorialViewModel.start()
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
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task { await session.signOut() }
            }
        } message: {
            Text("This removes your data from this device. It stays safe in your account and comes back when you sign in.")
        }
        .task {
            await pulsePlusService.refreshSubscriptionStatus()
            await social.loadFriends()
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

    private var handleLine: String {
        let raw = (user?.username.isEmpty == false ? user?.username : user?.name) ?? "athlete"
        var parts = ["@" + raw.lowercased().replacingOccurrences(of: " ", with: "")]
        if let split = user?.selectedSplit?.name, !split.isEmpty { parts.append(split.uppercased()) }
        return parts.joined(separator: " · ")
    }

    private var statsRow: some View {
        let stats: [(String, String)] = [
            ("\(workouts.count)", "WORKOUTS"),
            ("\(streak)D", "STREAK"),
            ("\(social.friends.count)", "FOLLOWERS"),
            ("\(social.friends.count)", "FOLLOWING"),
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

    // MARK: - Pulse+ banner (free plan only)

    private var plusBanner: some View {
        Button { screen = .pulsePlus } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.18))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("UNLOCK PULSE+")
                        .font(.archivo(18, weight: .black))
                        .tracking(1.2)
                        .foregroundStyle(.white)
                    Text("SMART SUGGESTIONS · CLOUD SYNC · ANALYTICS")
                        .font(.spaceMono(9))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                Text("›").font(.spaceMono(16, weight: .bold)).foregroundStyle(.white)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color.pumpAccent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }
}

/// Lets deep links (e.g. a locked widget) ask the More tab to open Pulse+ even before it has appeared.
@Observable
final class MoreRouter {
    static let shared = MoreRouter()
    var pendingPulsePlus = false
}

// MARK: - Screen enum

private enum MoreScreen {
    case hub, history, profile, settings, equipment, pulsePlus, weeklyRecap, dataImport, privacy, widgets
}

#if DEBUG
private extension MoreScreen {
    static var debugInitial: MoreScreen {
        switch UserDefaults.standard.string(forKey: "debugMoreScreen") {
        case "history": .history
        case "profile": .profile
        case "settings": .settings
        case "equipment": .equipment
        case "pulsePlus": .pulsePlus
        case "weeklyRecap": .weeklyRecap
        case "dataImport": .dataImport
        case "privacy": .privacy
        case "widgets": .widgets
        default: .hub
        }
    }
}
#endif
