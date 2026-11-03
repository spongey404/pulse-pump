import SwiftUI
import SwiftData

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Settings (design "Ore Settings"): list rows with a title and a one-line description, no icon boxes, every switch an
/// `OreToggle`, every picker a segmented control under its description. Rows that open a page push it with the same transition
/// as the More list (`OrePushStack`).
struct SettingsView: View {
    enum Page: Hashable { case profile, gender, calorie, split, summary, data, equipment, widgets }

    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthSession.self) private var session
    @Query private var users: [User]
    @State private var supernovaService = SupernovaService()
    @State private var page: Page?
    @State private var showPaywall = false

    @AppStorage("calorieFormula") private var calorieFormulaRaw = ""
    @AppStorage("restTimerMode") private var restTimerModeRaw = ""
    @AppStorage("restTimerAlertType") private var alertTypeRaw = ""
    @AppStorage("appTheme") private var themeRaw = ""
    @AppStorage("smartWeightSuggestions") private var smartSuggestions = true
    @AppStorage("autoShareToFeed") private var autoShare = true
    @AppStorage("workoutReminders") private var workoutReminders = false
    @AppStorage("restDayAlerts") private var restDayAlerts = false
    /// Privacy lives in `PrivacyService`: saved locally, at users/{uid}.privacy and on the public profile.
    @State private var privacyService = SocialServices.privacy

    private var user: User? { users.first }
    private var hasSupernova: Bool { supernovaService.isSubscribed || supernovaService.isInFreeTrial }
    private var isMember: Bool { supernovaService.isSubscribed }
    private var goBack: () -> Void { onBack ?? { dismiss() } }

    var body: some View {
        OrePushStack(isOpen: page != nil) {
            mainContent
        } page: {
            if let user, let current = page { destination(current, user: user) }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await supernovaService.refreshSubscriptionStatus() }
        .sheet(isPresented: $showPaywall) { SupernovaView(onBack: { showPaywall = false }) }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            MoreScreenHeader(title: "SETTINGS", onBack: goBack)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if let user { sections(user: user) }
                    Color.clear.frame(height: 40)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
    }

    @ViewBuilder
    private func destination(_ page: Page, user: User) -> some View {
        let close = { self.page = nil }
        switch page {
        case .profile: EditProfilePage(user: user, onBack: close)
        case .gender: GenderPage(user: user, onBack: close)
        case .calorie: CalorieFormulaPage(hasSupernova: hasSupernova, onBack: close)
        case .split: SplitPage(user: user, onBack: close)
        case .summary: SummaryDisplayPage(onBack: close)
        case .data: DataExportView(onBack: close)
        case .equipment: EquipmentProfilesView(onBack: close)
        case .widgets: WidgetsView(onBack: close)
        }
    }

    @ViewBuilder
    private func sections(user: User) -> some View {
        MoreSectionLabel(title: "ACCOUNT", top: 22)
        MoreRow(label: "Edit profile", description: "Name, username and body measurements.") { page = .profile }

        MoreSectionLabel(title: "UNITS & BODY")
        OreSegmentedRow(label: "Weight unit", options: [("KG", UnitPreference.kg), ("LB", UnitPreference.lbs)],
                        selection: Binding(get: { user.unitPreference }, set: { user.unitPreference = $0; user.markUpdated() }))
        MoreRow(label: "Gender", description: "Used for calorie estimates.", value: user.gender.displayName.uppercased()) { page = .gender }
        OreSegmentedRow(label: "Experience level", description: "Sets how quickly suggested weights go up.",
                        options: [("NEW", ExperienceLevel.beginner), ("SOME", .intermediate), ("ADVANCED", .experienced)],
                        selection: Binding(get: { user.experienceLevel }, set: { user.experienceLevel = $0; user.markUpdated() }))

        MoreSectionLabel(title: "WORKOUT")
        smartSuggestionRows(user: user)
        OreSegmentedRow(label: "Rest timer", description: "Auto starts the timer when you complete a set.",
                        options: [("AUTO", RestTimerMode.autoStart), ("MANUAL", .manual), ("AUTO · DISMISS", .autoStartWithDismiss)],
                        selection: restTimerModeBinding)
        OreSegmentedRow(label: "Timer alert",
                        options: [("SOUND", AlertType.sound), ("HAPTIC", .vibration), ("BOTH", .both), ("SILENT", .silent)],
                        selection: alertTypeBinding)
        MoreRow(label: "Calorie formula", description: hasSupernova ? "Uses heart rate and body weight when available." : "Advanced formula comes with Supernova.",
                value: (hasSupernova ? calorieFormulaBinding.wrappedValue : .basic) == .basic ? "BASIC" : "ADVANCED") { page = .calorie }

        MoreSectionLabel(title: "APPEARANCE")
        OreSegmentedRow(label: "Theme", options: [("SYSTEM", AppTheme.system), ("LIGHT", .light), ("DARK", .dark)], selection: themeBinding)
        MoreRow(label: "Simple body map", description: "Shows muscle groups without the detailed heatmap.", value: "COMING SOON", chevron: false, isStatic: true)
        if isMember {
            MoreRow(label: "Accent colour", description: "Change it on your Supernova page.", value: AccentStore.shared.pickedName.uppercased()) {
                MoreRouter.shared.pendingSupernova = true
            }
            MoreRow(label: "Stardust buttons", description: "Adds Stardust to every accent button. Uses a little more battery.",
                    toggle: Binding(get: { AccentStore.shared.stardustSetting }, set: { AccentStore.shared.setStardustEnabled($0) }))
                .accessibilityIdentifier(AX.supernova.stardustEnabled)
        }

        MoreSectionLabel(title: "TRAINING")
        MoreRow(label: "Training split", value: splitValue(user)) { page = .split }

        MoreSectionLabel(title: "POST-WORKOUT")
        MoreRow(label: "Auto-share to feed", description: "Posts your summary when you finish a workout.", toggle: $autoShare)
        MoreRow(label: "Summary display", description: "Choose what shows on the workout summary.", value: summaryValue) { page = .summary }

        MoreSectionLabel(title: "PRIVACY")
        OreSegmentedRow(label: "Profile visibility", description: "Who can see your profile and workouts.",
                        options: PrivacyRow.profile.options.map { ($0.displayName.uppercased(), $0) }, selection: profilePrivacyBinding)

        MoreSectionLabel(title: "NOTIFICATIONS")
        MoreRow(label: "Workout reminders", description: "On your training days, at your usual time.", toggle: workoutRemindersBinding(user: user))
        MoreRow(label: "Rest day alerts", description: "A note on scheduled rest days.", toggle: restDayAlertsBinding(user: user))
        // Rows labelled COMING SOON have nothing behind them yet (no feature / no push pipeline), so they are not switches:
        // a toggle that does nothing is worse than an honest label.
        MoreRow(label: "Social activity", description: "Likes, comments and new followers.", value: "COMING SOON", chevron: false, isStatic: true)
        MoreRow(label: "Challenge updates", description: "Progress and results for challenges you join.", value: "COMING SOON", chevron: false, isStatic: true)

        MoreSectionLabel(title: "DATA")
        MoreRow(label: "Import / export", value: "STRONG · HEVY · CSV") { page = .data }
        MoreRow(label: "Equipment profiles", description: "Plates and bars available at each gym.") { page = .equipment }
        MoreRow(label: "Widgets", description: "Home Screen and Lock Screen widgets.", tag: "SUPERNOVA") {
            if hasSupernova { page = .widgets } else { showPaywall = true }
        }

        MoreSectionLabel(title: "ABOUT")
        MoreRow(label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0", chevron: false, isStatic: true)
    }

    private func splitValue(_ user: User) -> String {
        guard let split = user.selectedSplit else { return "" }
        let name = MoreTabView.shortSplit(split.name)
        if let days = split.type.daysPerWeek { return "\(name) · \(days) DAYS" }
        return name
    }

    private var summaryValue: String {
        let keys = ["summary_showDuration", "summary_showCalories", "summary_showMuscles", "summary_showPRs", "summary_showImprovement"]
        let on = keys.filter { UserDefaults.standard.object(forKey: $0) as? Bool ?? true }.count
        return "\(on) OF \(keys.count)"
    }

    // MARK: - Smart weight suggestions (Supernova)

    /// Master switch + increment. Free users see a SUPERNOVA row that opens the paywall.
    @ViewBuilder
    private func smartSuggestionRows(user: User) -> some View {
        let description = "Suggests the next weight on every set, based on your last session."
        if hasSupernova {
            MoreRow(label: "Smart weight suggestions", description: description, toggle: $smartSuggestions)
                .accessibilityIdentifier("settings.smartWeightSuggestions")
            if smartSuggestions {
                let unit = user.unitPreference
                let current = unit.display(user.effectiveProgressionIncrementKg)
                OreSegmentedRow(label: "Progression increment",
                                options: ProgressionRule.incrementChoices(unit).map { ("+\(UnitPreference.trim($0)) \(unit.label.uppercased())", $0) },
                                selection: Binding(
                                    get: { ProgressionRule.incrementChoices(unit).min { abs($0 - current) < abs($1 - current) } ?? current },
                                    set: { user.setProgressionIncrementKg(unit.kg(fromDisplay: $0)) }))
                    .accessibilityIdentifier("settings.progressionIncrement")
            }
        } else {
            MoreRow(label: "Smart weight suggestions", description: description, tag: "SUPERNOVA") { showPaywall = true }
                .accessibilityIdentifier("settings.smartWeightSuggestions")
        }
    }

    // MARK: - Bindings

    private var calorieFormulaBinding: Binding<CalorieFormula> {
        Binding(get: { CalorieFormula(rawValue: calorieFormulaRaw) ?? .basic },
                set: { calorieFormulaRaw = $0.rawValue })
    }

    private var restTimerModeBinding: Binding<RestTimerMode> {
        Binding(get: { RestTimerMode(rawValue: restTimerModeRaw) ?? .autoStart },
                set: { restTimerModeRaw = $0.rawValue })
    }

    private var alertTypeBinding: Binding<AlertType> {
        Binding(get: { AlertType(rawValue: alertTypeRaw) ?? .sound },
                set: { alertTypeRaw = $0.rawValue })
    }

    private var themeBinding: Binding<AppTheme> {
        Binding(get: { AppTheme(rawValue: themeRaw) ?? .system },
                set: { themeRaw = $0.rawValue })
    }

    private var profilePrivacyBinding: Binding<PrivacyLevel> {
        Binding(get: { privacyService.settings.profile },
                set: { level in Task { await SocialServices.viewModel.setPrivacy(.profile, level) } })
    }

    private func workoutRemindersBinding(user: User) -> Binding<Bool> {
        Binding(
            get: { workoutReminders },
            set: { newValue in
                workoutReminders = newValue
                Task {
                    if newValue, await NotificationService.shared.requestPermission() {
                        await NotificationService.shared.scheduleWorkoutReminders(split: user.selectedSplit)
                    } else {
                        NotificationService.shared.cancelWorkoutReminders()
                    }
                }
            }
        )
    }

    private func restDayAlertsBinding(user: User) -> Binding<Bool> {
        Binding(
            get: { restDayAlerts },
            set: { newValue in
                restDayAlerts = newValue
                Task {
                    if newValue, await NotificationService.shared.requestPermission() {
                        await NotificationService.shared.scheduleRestDayAlerts(split: user.selectedSplit)
                    } else {
                        NotificationService.shared.cancelRestDayAlerts()
                    }
                }
            }
        )
    }
}
