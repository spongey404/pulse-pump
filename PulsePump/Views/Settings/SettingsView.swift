import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]

    private var user: User? { users.first }

    var body: some View {
        List {
            if let user {
                accountSection(user: user)
                measurementsSection(user: user)
                workoutSection
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

    // MARK: - Notifications

    private var notificationSection: some View {
        Section("Notifications") {
            Toggle("Workout Reminders", isOn: workoutRemindersBinding)
            Toggle("Rest Day Alerts", isOn: restDayAlertsBinding)
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
                Text("Import / Export — Coming Soon")
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

    // MARK: - Actions

    private func signOut() {
        try? FirebaseAuthService().signOut()
    }
}
