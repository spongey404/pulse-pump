import SwiftUI
import SwiftData

// The pages Settings pushes (design "Ore Settings"): each has the standard header, the list-row style and, where it saves, the
// docked SAVE button (with Stardust when the member has it on).

/// A single-select row: title, optional description, a tag, and a ✓ in the accent on the chosen one. A locked row is half-faded.
struct OreSelectRow: View {
    let label: String
    var description: String? = nil
    var tag: String = ""
    var selected: Bool
    var locked = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 16) {
                    Text(label).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 8) {
                        if !tag.isEmpty { Text(tag).font(.spaceMono(8, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkMuted) }
                        Text(selected ? "✓" : "").font(.spaceMono(14, weight: .bold)).foregroundStyle(Color.accentInk).frame(width: 14)
                    }
                }
                if let description, !description.isEmpty {
                    Text(description).font(.archivo(12)).foregroundStyle(Color.inkMuted)
                        .cssLineHeight(fontName: "Archivo-Regular", size: 12, multiple: 1.4)
                        .fixedSize(horizontal: false, vertical: true).frame(maxWidth: 290, alignment: .leading)
                }
            }
            .padding(.vertical, 14).padding(.horizontal, 16)
            .frame(minHeight: 44).frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            .contentShape(Rectangle())
            .opacity(locked ? 0.5 : 1)
        }
        .buttonStyle(OreRowPressStyle())
        .disabled(locked)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(AX.row(label))
    }
}

// MARK: - Gender

struct GenderPage: View {
    @Bindable var user: User
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            MoreScreenHeader(title: "GENDER", onBack: onBack)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    MorePageIntro(text: "Used for calorie estimates. Not shown on your profile.")
                    Rectangle().fill(Color.dsHairLine).frame(height: 1).padding(.top, 4)
                    ForEach(Gender.allCases) { g in
                        OreSelectRow(label: g.displayName,
                                     description: g == .preferNotToSay ? "Calories use an average of both formulas." : nil,
                                     selected: user.gender == g) { user.gender = g; user.markUpdated() }
                    }
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
    }
}

// MARK: - Calorie formula

struct CalorieFormulaPage: View {
    let hasSupernova: Bool
    let onBack: () -> Void
    @AppStorage("calorieFormula") private var raw = ""

    private var current: CalorieFormula { hasSupernova ? (CalorieFormula(rawValue: raw) ?? .basic) : .basic }

    var body: some View {
        VStack(spacing: 0) {
            MoreScreenHeader(title: "CALORIE FORMULA", onBack: onBack)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    MoreSectionLabel(title: "FORMULA")
                    OreSelectRow(label: "Basic", description: "Duration × body weight × workout type.", selected: current == .basic) { raw = CalorieFormula.basic.rawValue }
                    OreSelectRow(label: "Advanced", description: "Adds heart rate, set volume and rest time when available.",
                                 tag: hasSupernova ? "" : "SUPERNOVA", selected: current == .met, locked: !hasSupernova) { raw = CalorieFormula.met.rawValue }
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
    }
}

// MARK: - Training split

struct SplitPage: View {
    let user: User
    let onBack: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var selectedType: SplitType = .ppl

    var body: some View {
        VStack(spacing: 0) {
            MoreScreenHeader(title: "TRAINING SPLIT", onBack: onBack)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    MoreSectionLabel(title: "SELECT SPLIT")
                    ForEach(SplitType.allCases) { type in
                        OreSelectRow(label: type.displayName,
                                     description: type.daysPerWeek.map { "\($0) DAYS/WK" } ?? "Build your own days.",
                                     selected: selectedType == type) { selectedType = type }
                    }
                }
            }
            OrePageFooter {
                OrePageCTA(title: "SAVE SPLIT") {
                    SplitSchedule.apply(type: selectedType, to: user, modelContext: modelContext)
                    user.markUpdated()
                    let split = user.selectedSplit
                    Task { await NotificationService.shared.reschedule(split: split) }
                    onBack()
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .onAppear { if let current = user.selectedSplit { selectedType = current.type } }
    }
}

// MARK: - Summary display

struct SummaryDisplayPage: View {
    let onBack: () -> Void
    @AppStorage("summary_showDuration") private var showDuration = true
    @AppStorage("summary_showCalories") private var showCalories = true
    @AppStorage("summary_showMuscles") private var showMuscles = true
    @AppStorage("summary_showPRs") private var showPRs = true
    @AppStorage("summary_showImprovement") private var showImprovement = true

    var body: some View {
        VStack(spacing: 0) {
            MoreScreenHeader(title: "SUMMARY DISPLAY", onBack: onBack)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    MoreSectionLabel(title: "VISIBLE ON POST-WORKOUT SUMMARY")
                    MoreRow(label: "Duration", toggle: $showDuration)
                    MoreRow(label: "Calories burned", toggle: $showCalories)
                    MoreRow(label: "Muscles worked", toggle: $showMuscles)
                    MoreRow(label: "PRs hit", toggle: $showPRs)
                    MoreRow(label: "Improvement count", toggle: $showImprovement)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
    }
}

// MARK: - Edit profile

struct EditProfilePage: View {
    @Bindable var user: User
    let onBack: () -> Void
    @Environment(AuthSession.self) private var session
    @State private var name: String
    @State private var weight: String
    @State private var height: String
    @State private var heightFeet: String
    @State private var heightInches: String
    @State private var age: String
    @State private var showChangeUsername = false
    /// What the fields started with: unchanged ones are never written back, so opening and saving can't drift stored kg/cm.
    private let initialWeight: String
    private let initialHeight: String
    @FocusState private var focus: Field?
    private enum Field { case name, weight, height, feet, inches, age }

    init(user: User, onBack: @escaping () -> Void) {
        self.user = user
        self.onBack = onBack
        _name = State(initialValue: user.name)
        let w = user.weight > 0 ? user.unitPreference.number(user.weight) : ""
        let h = user.height > 0 ? String(format: "%g", user.height.rounded()) : ""
        let ftIn = UnitPreference.feetInches(fromCm: user.height)
        _weight = State(initialValue: w)
        _height = State(initialValue: h)
        _heightFeet = State(initialValue: user.height > 0 ? "\(ftIn.feet)" : "")
        _heightInches = State(initialValue: user.height > 0 ? "\(ftIn.inches)" : "")
        initialWeight = w
        initialHeight = h
        _age = State(initialValue: user.age > 0 ? "\(user.age)" : "")
    }

    var body: some View {
        VStack(spacing: 0) {
            MoreScreenHeader(title: "EDIT PROFILE", onBack: onBack)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    avatar
                    Rectangle().fill(Color.dsHairLine).frame(height: 1)
                    field("NAME") { input("Name", text: $name, field: .name) }
                    field("USERNAME") {
                        Button { showChangeUsername = true } label: {
                            HStack {
                                Text(user.username.isEmpty ? "—" : "@\(user.username)").font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
                                Spacer()
                                Text("CHANGE").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.accentInk)
                            }
                            .padding(.horizontal, 12).frame(height: 40).background(Color.surf2)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    field("WEIGHT · \(user.unitPreference.lowercaseLabel.uppercased())") { input("Weight", text: $weight, field: .weight, keyboard: .decimalPad) }
                    if user.unitPreference == .lbs {
                        field("HEIGHT · FT / IN") {
                            HStack(spacing: 8) {
                                input("Feet", text: $heightFeet, field: .feet, keyboard: .numberPad)
                                input("Inches", text: $heightInches, field: .inches, keyboard: .numberPad)
                            }
                        }
                    } else {
                        field("HEIGHT · CM") { input("Height", text: $height, field: .height, keyboard: .decimalPad) }
                    }
                    field("AGE") { input("Age", text: $age, field: .age, keyboard: .numberPad) }
                    MoreRow(label: "Email", value: session.user?.email ?? "—", chevron: false, isStatic: true)
                    MoreRow(label: "Signed in with", value: (session.user?.providerSummary ?? "").uppercased(), chevron: false, isStatic: true)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            OrePageFooter {
                OrePageCTA(title: "SAVE", disabled: name.trimmingCharacters(in: .whitespaces).isEmpty) { save(); onBack() }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .sheet(isPresented: $showChangeUsername) { ChangeUsernameSheet(user: user) }
    }

    /// The 64 pt avatar tile in the accent (Stardust behind the initial when the member has it on).
    private var avatar: some View {
        HStack(spacing: 14) {
            ZStack {
                Color.oreAccent
                if AccentStore.shared.stardustEnabled {
                    StardustView(variant: "avatar", budget: .more,
                                 overrides: StardustParams.Overrides(palette: AccentStore.shared.starPalette, density: 1600, gold: 0.4, sparkle: 0.55, fps: 30))
                        .allowsHitTesting(false)
                }
                Text(String(user.name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                    .font(.archivo(28, weight: .black)).foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 18)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
            content()
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func input(_ placeholder: String, text: Binding<String>, field f: Field, keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .focused($focus, equals: f)
            .font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
            .padding(.horizontal, 12).frame(height: 40)
            .background(Color.surf2)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay { if focus == f { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.oreAccent, lineWidth: 1.5) } }
    }

    private func save() {
        user.name = name.trimmingCharacters(in: .whitespaces)
        if weight != initialWeight, let kg = user.unitPreference.parseKg(weight), kg > 0 {
            user.weight = kg
            BodyweightLog.record(kg: kg)
        }
        if user.unitPreference == .lbs {
            let ftIn = UnitPreference.feetInches(fromCm: user.height)
            if "\(ftIn.feet)" != heightFeet || "\(ftIn.inches)" != heightInches,
               let ft = parseDecimal(heightFeet), ft > 0 {
                user.height = UnitPreference.cm(feet: ft, inches: parseDecimal(heightInches) ?? 0)
            }
        } else if height != initialHeight, let h = parseDecimal(height), h > 0 {
            user.height = h
        }
        if let a = parseWholeNumber(age) { user.age = a }
        user.markUpdated()
    }
}
