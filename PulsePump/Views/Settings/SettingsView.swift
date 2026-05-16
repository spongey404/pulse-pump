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
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @State private var pulsePlusService = PulsePlusService()
    @State private var navigateToEditProfile = false
    @State private var navigateToSplitConfig = false
    @State private var navigateToDataExport = false
    @State private var navigateToEquipment = false
    @State private var showSignOutAlert = false

    private var user: User? { users.first }
    private var hasPulsePlus: Bool { pulsePlusService.isSubscribed || pulsePlusService.isInFreeTrial }

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if let user {
                        buildSections(user: user)
                    }
                    Color.clear.frame(height: 40)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .task { await pulsePlusService.refreshSubscriptionStatus() }
        .navigationDestination(isPresented: $navigateToEditProfile) {
            if let user { EditProfileView(user: user) }
        }
        .navigationDestination(isPresented: $navigateToSplitConfig) {
            if let user { SplitConfigView(user: user) }
        }
        .navigationDestination(isPresented: $navigateToDataExport) {
            DataExportView()
        }
        .navigationDestination(isPresented: $navigateToEquipment) {
            EquipmentProfilesView()
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) { signOut() }
        } message: {
            Text("You'll need to sign back in to access your data.")
        }
    }

    @ViewBuilder
    private func buildSections(user: User) -> some View {
        // ACCOUNT
        sectionLabel("ACCOUNT")
        navRow(icon: "person.crop.circle", label: "Edit Profile") { navigateToEditProfile = true }

        // UNITS & MEASUREMENTS
        sectionLabel("UNITS & MEASUREMENTS")
        pickerRow(icon: "scalemass", label: "Weight Unit") {
            Picker("Weight Unit", selection: Binding(
                get: { user.unitPreference },
                set: { user.unitPreference = $0; user.updatedAt = Date() }
            )) {
                ForEach(UnitPreference.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
        }
        pickerRow(icon: "person.fill", label: "Gender") {
            Picker("Gender", selection: Binding(
                get: { user.gender },
                set: { user.gender = $0; user.updatedAt = Date() }
            )) {
                ForEach(Gender.allCases) { gender in
                    Text(gender.displayName).tag(gender)
                }
            }
        }
        pickerRow(icon: "chart.bar", label: "Experience Level") {
            Picker("Experience", selection: Binding(
                get: { user.experienceLevel },
                set: { user.experienceLevel = $0; user.updatedAt = Date() }
            )) {
                ForEach(ExperienceLevel.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
        }

        // WORKOUT
        sectionLabel("WORKOUT")
        pickerRow(icon: "flame", label: "Calorie Formula") {
            Picker("Calorie Formula", selection: calorieFormulaBinding) {
                ForEach(hasPulsePlus ? CalorieFormula.allCases : [.basic]) { formula in
                    Text(formula.displayName).tag(formula)
                }
            }
        }
        pickerRow(icon: "timer", label: "Rest Timer Mode") {
            Picker("Rest Timer Mode", selection: restTimerModeBinding) {
                ForEach(RestTimerMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
        }
        pickerRow(icon: "bell", label: "Timer Alert") {
            Picker("Timer Alert", selection: alertTypeBinding) {
                ForEach(AlertType.allCases) { alert in
                    Text(alert.displayName).tag(alert)
                }
            }
        }
        toggleRow(icon: "brain", label: "Smart Weight Suggestions", binding: smartSuggestionsBinding)

        // APPEARANCE
        sectionLabel("APPEARANCE")
        pickerRow(icon: "paintbrush", label: "Theme") {
            Picker("Theme", selection: themeBinding) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
        }
        toggleRow(icon: "figure.stand", label: "Simple Body Map", binding: simpleBodyMapBinding)

        // TRAINING
        sectionLabel("TRAINING")
        navRow(icon: "calendar.badge.clock", label: "Training Split") { navigateToSplitConfig = true }

        // POST-WORKOUT
        sectionLabel("POST-WORKOUT")
        toggleRow(icon: "square.and.arrow.up", label: "Auto-Share to Feed", binding: autoShareBinding)

        // NOTIFICATIONS
        sectionLabel("NOTIFICATIONS")
        toggleRow(icon: "bell.badge", label: "Workout Reminders", binding: workoutRemindersBinding(user: user))
        toggleRow(icon: "moon", label: "Rest Day Alerts", binding: restDayAlertsBinding(user: user))
        toggleRow(icon: "person.2", label: "Social Activity", binding: socialNotificationsBinding)
        toggleRow(icon: "trophy", label: "Challenge Updates", binding: challengeNotificationsBinding)

        // DATA
        sectionLabel("DATA")
        navRow(icon: "square.and.arrow.down", label: "Import / Export Data") { navigateToDataExport = true }
        navRow(icon: "dumbbell", label: "Equipment Profiles") { navigateToEquipment = true }

        // ABOUT
        sectionLabel("ABOUT")
        valueRow(icon: "info.circle", label: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")

        // DANGER ZONE
        sectionLabel("")
        dangerRow(icon: "rectangle.portrait.and.arrow.right", label: "Sign Out") { showSignOutAlert = true }
    }

    // MARK: - Header

    private var settingsHeader: some View {
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
                Text("SETTINGS")
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

    // MARK: - Row builders

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.spaceMono(9))
            .tracking(1.5)
            .foregroundStyle(Color.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, title.isEmpty ? 4 : 14)
            .padding(.bottom, 4)
    }

    private func navRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        settingsRowWrapper {
            Button(action: action) {
                HStack(spacing: 12) {
                    iconBox(icon)
                    Text(label)
                        .font(.archivo(14, weight: .medium))
                        .foregroundStyle(Color.inkPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.inkPrimary.opacity(0.2))
                }
                .padding(.vertical, 13)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
        }
    }

    private func pickerRow<C: View>(icon: String, label: String, @ViewBuilder content: () -> C) -> some View {
        settingsRowWrapper {
            HStack(spacing: 12) {
                iconBox(icon)
                Text(label)
                    .font(.archivo(14, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                content()
                    .labelsHidden()
                    .font(.spaceMono(11))
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
        }
    }

    private func toggleRow(icon: String, label: String, binding: Binding<Bool>) -> some View {
        settingsRowWrapper {
            HStack(spacing: 12) {
                iconBox(icon)
                Text(label)
                    .font(.archivo(14, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Toggle("", isOn: binding)
                    .labelsHidden()
                    .tint(Color.pumpAccent)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
        }
    }

    private func valueRow(icon: String, label: String, value: String) -> some View {
        settingsRowWrapper {
            HStack(spacing: 12) {
                iconBox(icon)
                Text(label)
                    .font(.archivo(14, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text(value)
                    .font(.spaceMono(11))
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
        }
    }

    private func dangerRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        settingsRowWrapper {
            Button(action: action) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.signalDown.opacity(0.10))
                            .frame(width: 32, height: 32)
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.signalDown)
                    }
                    Text(label)
                        .font(.archivo(14, weight: .medium))
                        .foregroundStyle(Color.signalDown)
                    Spacer()
                }
                .padding(.vertical, 13)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func settingsRowWrapper<C: View>(@ViewBuilder content: () -> C) -> some View {
        VStack(spacing: 0) {
            content()
            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
        .background(Color.canvasBg)
    }

    private func iconBox(_ icon: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.surf2)
                .frame(width: 32, height: 32)
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.inkMuted)
        }
    }

    // MARK: - Bindings

    private var calorieFormulaBinding: Binding<CalorieFormula> {
        Binding(
            get: { CalorieFormula(rawValue: UserDefaults.standard.string(forKey: "calorieFormula") ?? "") ?? .basic },
            set: { UserDefaults.standard.set($0.rawValue, forKey: "calorieFormula") }
        )
    }

    private var restTimerModeBinding: Binding<RestTimerMode> {
        Binding(
            get: { RestTimerMode(rawValue: UserDefaults.standard.string(forKey: "restTimerMode") ?? "") ?? .autoStart },
            set: { UserDefaults.standard.set($0.rawValue, forKey: "restTimerMode") }
        )
    }

    private var alertTypeBinding: Binding<AlertType> {
        Binding(
            get: { AlertType(rawValue: UserDefaults.standard.string(forKey: "restTimerAlertType") ?? "") ?? .sound },
            set: { UserDefaults.standard.set($0.rawValue, forKey: "restTimerAlertType") }
        )
    }

    private var smartSuggestionsBinding: Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.object(forKey: "smartWeightSuggestions") as? Bool ?? true },
            set: { UserDefaults.standard.set($0, forKey: "smartWeightSuggestions") }
        )
    }

    private var themeBinding: Binding<AppTheme> {
        Binding(
            get: { AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "") ?? .system },
            set: { UserDefaults.standard.set($0.rawValue, forKey: "appTheme") }
        )
    }

    private var autoShareBinding: Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.object(forKey: "autoShareToFeed") as? Bool ?? true },
            set: { UserDefaults.standard.set($0, forKey: "autoShareToFeed") }
        )
    }

    private var simpleBodyMapBinding: Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.bool(forKey: "simpleBodyMap") },
            set: { UserDefaults.standard.set($0, forKey: "simpleBodyMap") }
        )
    }

    private func workoutRemindersBinding(user: User) -> Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.bool(forKey: "workoutReminders") },
            set: { newValue in
                UserDefaults.standard.set(newValue, forKey: "workoutReminders")
                Task {
                    let granted = await NotificationService.shared.requestPermission()
                    if granted {
                        await NotificationService.shared.scheduleWorkoutReminders(split: user.selectedSplit)
                    } else if !newValue {
                        NotificationService.shared.cancelWorkoutReminders()
                    }
                }
            }
        )
    }

    private func restDayAlertsBinding(user: User) -> Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.bool(forKey: "restDayAlerts") },
            set: { newValue in
                UserDefaults.standard.set(newValue, forKey: "restDayAlerts")
                Task {
                    let granted = await NotificationService.shared.requestPermission()
                    if granted {
                        await NotificationService.shared.scheduleRestDayAlerts(split: user.selectedSplit)
                    } else if !newValue {
                        NotificationService.shared.cancelRestDayAlerts()
                    }
                }
            }
        )
    }

    private var socialNotificationsBinding: Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.object(forKey: "socialNotifications") as? Bool ?? true },
            set: { UserDefaults.standard.set($0, forKey: "socialNotifications") }
        )
    }

    private var challengeNotificationsBinding: Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.object(forKey: "challengeNotifications") as? Bool ?? true },
            set: { UserDefaults.standard.set($0, forKey: "challengeNotifications") }
        )
    }

    // MARK: - Actions

    private func signOut() {
        try? FirebaseAuthService().signOut()
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
                                    .foregroundStyle(Color.pumpAccent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                Button("Save Split") {
                    let split = Split(type: selectedType, name: selectedType.displayName)
                    modelContext.insert(split)
                    user.selectedSplit = split
                    user.updatedAt = Date()
                    dismiss()
                }
                .font(.archivo(16, weight: .semibold))
                .foregroundStyle(Color.pumpAccent)
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
