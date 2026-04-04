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
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Query private var splits: [Split]

    private var user: User? { users.first }

    var body: some View {
        List {
            if let user {
                accountSection(user: user)
                measurementsSection(user: user)
                appearanceSection
                workoutSection
                postWorkoutSection
                splitSection(user: user)
                notificationSection
                dataSection
                aboutSection
            }
        }
        .navigationTitle("Settings")
    }

    // MARK: - Account

    private func accountSection(user: User) -> some View {
        Section("Account") {
            HStack {
                Text("Name")
                Spacer()
                Text(user.name)
                    .foregroundStyle(.secondary)
            }

            NavigationLink {
                EditProfileView(user: user)
            } label: {
                Text("Edit Profile")
            }

            Button("Sign Out", role: .destructive) {
                signOut()
            }
        }
    }

    // MARK: - Measurements

    private func measurementsSection(user: User) -> some View {
        Section("Units & Measurements") {
            Picker("Weight Unit", selection: Binding(
                get: { user.unitPreference },
                set: { user.unitPreference = $0; user.updatedAt = Date() }
            )) {
                ForEach(UnitPreference.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }

            Picker("Gender", selection: Binding(
                get: { user.gender },
                set: { user.gender = $0; user.updatedAt = Date() }
            )) {
                ForEach(Gender.allCases) { gender in
                    Text(gender.displayName).tag(gender)
                }
            }

            Picker("Experience", selection: Binding(
                get: { user.experienceLevel },
                set: { user.experienceLevel = $0; user.updatedAt = Date() }
            )) {
                ForEach(ExperienceLevel.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: themeBinding) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
        }
    }

    // MARK: - Workout

    private var workoutSection: some View {
        Section("Workout") {
            Picker("Calorie Formula", selection: calorieFormulaBinding) {
                ForEach(CalorieFormula.allCases) { formula in
                    Text(formula.displayName).tag(formula)
                }
            }

            Picker("Rest Timer Mode", selection: restTimerModeBinding) {
                ForEach(RestTimerMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            Picker("Timer Alert", selection: alertTypeBinding) {
                ForEach(AlertType.allCases) { alert in
                    Text(alert.displayName).tag(alert)
                }
            }

            HStack {
                Text("Compound Rest (sec)")
                Spacer()
                Text("\(compoundRest)")
                    .foregroundStyle(.secondary)
                Stepper("", value: compoundRestBinding, in: 30...600, step: 15)
                    .labelsHidden()
            }

            HStack {
                Text("Isolation Rest (sec)")
                Spacer()
                Text("\(isolationRest)")
                    .foregroundStyle(.secondary)
                Stepper("", value: isolationRestBinding, in: 30...600, step: 15)
                    .labelsHidden()
            }
        }
    }

    // MARK: - Post-Workout

    private var postWorkoutSection: some View {
        Section("Post-Workout") {
            Toggle("Auto-Share to Feed", isOn: autoShareBinding)
            NavigationLink {
                PostWorkoutCustomizationView()
            } label: {
                Text("Summary Customization")
            }
        }
    }

    // MARK: - Split Configuration

    private func splitSection(user: User) -> some View {
        Section("Training Split") {
            if let split = user.selectedSplit {
                HStack {
                    Text("Current Split")
                    Spacer()
                    Text(split.name)
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    SplitConfigView(user: user)
                } label: {
                    Text("Change Split")
                }
            } else {
                NavigationLink {
                    SplitConfigView(user: user)
                } label: {
                    Text("Set Up Training Split")
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationSection: some View {
        Section("Notifications") {
            Toggle("Workout Reminders", isOn: workoutRemindersBinding)
            Toggle("Rest Day Alerts", isOn: restDayAlertsBinding)
            Toggle("Social Activity", isOn: socialNotificationsBinding)
            Toggle("Challenge Updates", isOn: challengeNotificationsBinding)
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section("Data") {
            NavigationLink {
                EquipmentProfilesView()
            } label: {
                Text("Equipment Profiles")
            }

            NavigationLink {
                DataExportView()
            } label: {
                Text("Import / Export Data")
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }

            NavigationLink {
                Text("Terms of Service — Coming Soon")
            } label: {
                Text("Terms of Service")
            }

            NavigationLink {
                Text("Privacy Policy — Coming Soon")
            } label: {
                Text("Privacy Policy")
            }
        }
    }

    // MARK: - UserDefaults Bindings

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

    private var compoundRest: Int {
        UserDefaults.standard.object(forKey: "compoundRestSeconds") as? Int ?? 180
    }

    private var compoundRestBinding: Binding<Int> {
        Binding(
            get: { compoundRest },
            set: { UserDefaults.standard.set($0, forKey: "compoundRestSeconds") }
        )
    }

    private var isolationRest: Int {
        UserDefaults.standard.object(forKey: "isolationRestSeconds") as? Int ?? 90
    }

    private var isolationRestBinding: Binding<Int> {
        Binding(
            get: { isolationRest },
            set: { UserDefaults.standard.set($0, forKey: "isolationRestSeconds") }
        )
    }

    private var workoutRemindersBinding: Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.bool(forKey: "workoutReminders") },
            set: { UserDefaults.standard.set($0, forKey: "workoutReminders") }
        )
    }

    private var restDayAlertsBinding: Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.bool(forKey: "restDayAlerts") },
            set: { UserDefaults.standard.set($0, forKey: "restDayAlerts") }
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
                                    .font(.body)
                                if let days = splitType.daysPerWeek {
                                    Text("\(days) days/week")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if selectedType == splitType {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.pumpPrimary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section {
                Button("Save") {
                    applySplit()
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(Color.pumpPrimary)
            }
        }
        .navigationTitle("Training Split")
        .onAppear {
            if let current = user.selectedSplit {
                selectedType = current.type
            }
        }
    }

    private func applySplit() {
        let split = Split(type: selectedType)
        modelContext.insert(split)
        user.selectedSplit = split
        user.updatedAt = Date()
    }
}
