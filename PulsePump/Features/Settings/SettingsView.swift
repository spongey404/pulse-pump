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

struct SettingsView: View {
    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthSession.self) private var session
    @Query private var users: [User]
    @State private var pulsePlusService = PulsePlusService()
    @State private var navigateToEditProfile = false
    @State private var navigateToSplitConfig = false
    @State private var showData = false
    @State private var showEquipment = false
    @State private var showSignOutAlert = false
    @State private var showDeleteAccount = false
    @State private var showChangeUsername = false

    @AppStorage("calorieFormula") private var calorieFormulaRaw = ""
    @AppStorage("restTimerMode") private var restTimerModeRaw = ""
    @AppStorage("restTimerAlertType") private var alertTypeRaw = ""
    @AppStorage("smartWeightSuggestions") private var smartSuggestions = true
    @AppStorage("appTheme") private var themeRaw = ""
    @AppStorage("autoShareToFeed") private var autoShare = true
    @AppStorage("simpleBodyMap") private var simpleBodyMap = false
    @AppStorage("workoutReminders") private var workoutReminders = false
    @AppStorage("restDayAlerts") private var restDayAlerts = false
    @AppStorage("socialNotifications") private var socialNotifications = true
    @AppStorage("challengeNotifications") private var challengeNotifications = true
    @AppStorage(PrivacyRow.profile.storageKey) private var profilePrivacyRaw = PrivacyLevel.friendsOnly.rawValue

    private var user: User? { users.first }
    private var hasPulsePlus: Bool { pulsePlusService.isSubscribed || pulsePlusService.isInFreeTrial }
    private var goBack: () -> Void { onBack ?? { dismiss() } }

    var body: some View {
        Group {
            if showData {
                DataExportView(onBack: { showData = false })
            } else if showEquipment {
                EquipmentProfilesView(onBack: { showEquipment = false })
            } else {
                mainContent
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await pulsePlusService.refreshSubscriptionStatus() }
        .navigationDestination(isPresented: $navigateToEditProfile) {
            if let user { EditProfileView(user: user) }
        }
        .navigationDestination(isPresented: $navigateToSplitConfig) {
            if let user { SplitConfigView(user: user) }
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) { signOut() }
        } message: {
            Text("This removes your data from this device. It stays safe in your account and comes back when you sign in.")
        }
        .sheet(isPresented: $showChangeUsername) {
            if let user { ChangeUsernameSheet(user: user) }
        }
        .deleteAccountFlow(isPresented: $showDeleteAccount)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            MoreScreenHeader(title: "SETTINGS", onBack: goBack)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if let user {
                        buildSections(user: user)
                    }
                    Color.clear.frame(height: 32)
                }
            }
        }
    }

    @ViewBuilder
    private func buildSections(user: User) -> some View {
        // ACCOUNT
        MoreSectionLabel(title: "ACCOUNT")
        MoreRow(icon: "person.crop.circle", label: "Edit Profile") { navigateToEditProfile = true }
        MoreRow(icon: "envelope", label: "Email", value: session.user?.email ?? "—", chevron: false) { }
        MoreRow(icon: "key", label: "Signed In With", value: (session.user?.providerSummary ?? "").uppercased(), chevron: false) { }
        MoreRow(icon: "at", label: "Username", value: user.username.isEmpty ? "—" : "@\(user.username)") {
            showChangeUsername = true
        }

        // UNITS & MEASUREMENTS
        MoreSectionLabel(title: "UNITS & MEASUREMENTS")
        MoreMenuRow(icon: "scalemass", label: "Weight Unit",
                    selection: Binding(get: { user.unitPreference },
                                       set: { user.unitPreference = $0; user.markUpdated() }),
                    options: Array(UnitPreference.allCases), title: { $0.displayName })
        MoreMenuRow(icon: "person.fill", label: "Gender",
                    selection: Binding(get: { user.gender },
                                       set: { user.gender = $0; user.markUpdated() }),
                    options: Array(Gender.allCases), title: { $0.displayName })
        MoreMenuRow(icon: "chart.bar", label: "Experience Level",
                    selection: Binding(get: { user.experienceLevel },
                                       set: { user.experienceLevel = $0; user.markUpdated() }),
                    options: Array(ExperienceLevel.allCases), title: { $0.displayName })

        // WORKOUT
        MoreSectionLabel(title: "WORKOUT")
        MoreMenuRow(icon: "flame", label: "Calorie Formula", selection: calorieFormulaBinding,
                    options: hasPulsePlus ? Array(CalorieFormula.allCases) : [.basic],
                    title: { $0.displayName })
        MoreMenuRow(icon: "timer", label: "Rest Timer Mode", selection: restTimerModeBinding,
                    options: Array(RestTimerMode.allCases), title: { $0.displayName })
            .tutorialTarget("rest-movement-defaults")
        MoreMenuRow(icon: "bell", label: "Timer Alert", selection: alertTypeBinding,
                    options: Array(AlertType.allCases), title: { $0.displayName })
        MoreRow(icon: "brain", label: "Smart Weight Suggestions", toggle: $smartSuggestions)

        // PRIVACY
        MoreSectionLabel(title: "PRIVACY")
        MoreMenuRow(icon: "eye", label: "Profile Visibility", selection: profilePrivacyBinding,
                    options: Array(PrivacyLevel.allCases), title: { $0.displayName })
        MoreRow(icon: "square.and.arrow.up", label: "Auto-Share to Feed", toggle: $autoShare)

        // APPEARANCE
        MoreSectionLabel(title: "APPEARANCE")
        MoreMenuRow(icon: "moon", label: "Theme", selection: themeBinding,
                    options: Array(AppTheme.allCases), title: { $0.displayName })
        MoreRow(icon: "figure.stand", label: "Simple Body Map", toggle: $simpleBodyMap)

        // TRAINING
        MoreSectionLabel(title: "TRAINING")
        MoreRow(icon: "calendar.badge.clock", label: "Training Split",
                value: user.selectedSplit?.name.uppercased() ?? "") { navigateToSplitConfig = true }

        // NOTIFICATIONS
        MoreSectionLabel(title: "NOTIFICATIONS")
        MoreRow(icon: "bell.badge", label: "Workout Reminders", toggle: workoutRemindersBinding(user: user))
        MoreRow(icon: "moon", label: "Rest Day Alerts", toggle: restDayAlertsBinding(user: user))
        MoreRow(icon: "person.2", label: "Social Activity", toggle: $socialNotifications)
        MoreRow(icon: "trophy", label: "Challenge Updates", toggle: $challengeNotifications)

        // DATA
        MoreSectionLabel(title: "DATA")
        MoreRow(icon: "square.and.arrow.down", label: "Import / Export Data") { showData = true }
        MoreRow(icon: "dumbbell", label: "Equipment Profiles") { showEquipment = true }

        // CLOUD SYNC
        CloudSyncSection()

        // ABOUT
        MoreSectionLabel(title: "ABOUT")
        MoreRow(icon: "info.circle", label: "Version",
                value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                chevron: false) { }

        // SIGN OUT
        MoreSectionLabel(title: "")
        MoreRow(icon: "rectangle.portrait.and.arrow.right", label: "Sign Out",
                destructive: true, chevron: false) { showSignOutAlert = true }
        MoreRow(icon: "trash", label: "Delete Account", destructive: true, chevron: false) { showDeleteAccount = true }
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
        Binding(get: { PrivacyLevel(rawValue: profilePrivacyRaw) ?? .friendsOnly },
                set: { profilePrivacyRaw = $0.rawValue })
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

    // MARK: - Actions

    private func signOut() {
        Task { await session.signOut() }
    }
}

// MARK: - Post-Workout Summary Customization

struct PostWorkoutCustomizationView: View {
    @State private var showDuration = UserDefaults.standard.object(forKey: "summary_showDuration") as? Bool ?? true
    @State private var showCalories = UserDefaults.standard.object(forKey: "summary_showCalories") as? Bool ?? true
    @State private var showMuscles = UserDefaults.standard.object(forKey: "summary_showMuscles") as? Bool ?? true
    @State private var showPRs = UserDefaults.standard.object(forKey: "summary_showPRs") as? Bool ?? true
    @State private var showImprovement = UserDefaults.standard.object(forKey: "summary_showImprovement") as? Bool ?? true

    var body: some View {
        List {
            Section("Visible on Post-Workout Summary") {
                Toggle("Duration", isOn: $showDuration)
                Toggle("Calories Burned", isOn: $showCalories)
                Toggle("Muscles Worked", isOn: $showMuscles)
                Toggle("PRs Hit", isOn: $showPRs)
                Toggle("Improvement Count", isOn: $showImprovement)
            }
        }
        .navigationTitle("Summary Display")
        .onChange(of: showDuration) { _, v in UserDefaults.standard.set(v, forKey: "summary_showDuration") }
        .onChange(of: showCalories) { _, v in UserDefaults.standard.set(v, forKey: "summary_showCalories") }
        .onChange(of: showMuscles) { _, v in UserDefaults.standard.set(v, forKey: "summary_showMuscles") }
        .onChange(of: showPRs) { _, v in UserDefaults.standard.set(v, forKey: "summary_showPRs") }
        .onChange(of: showImprovement) { _, v in UserDefaults.standard.set(v, forKey: "summary_showImprovement") }
    }
}

// MARK: - Split Configuration

struct SplitConfigView: View {
    let user: User
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: SplitType = .ppl

    var body: some View {
        List {
            Section("Select Split Type") {
                ForEach(SplitType.allCases) { splitType in
                    Button {
                        selectedType = splitType
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(splitType.displayName)
                                    .font(.archivo(16))
                                    .foregroundStyle(Color.inkPrimary)
                                if let days = splitType.daysPerWeek {
                                    Text("\(days) days/week")
                                        .font(.spaceMono(11))
                                        .foregroundStyle(Color.inkMuted)
                                }
                            }
                            Spacer()
                            if selectedType == splitType {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentInk)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                Button("Save Split") {
                    SplitSchedule.apply(type: selectedType, to: user, modelContext: modelContext)
                    user.markUpdated()
                    let split = user.selectedSplit
                    Task { await NotificationService.shared.reschedule(split: split) }
                    dismiss()
                }
                .font(.archivo(16, weight: .semibold))
                .foregroundStyle(Color.accentInk)
            }
        }
        .navigationTitle("Training Split")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let current = user.selectedSplit {
                selectedType = current.type
            }
        }
    }
}
