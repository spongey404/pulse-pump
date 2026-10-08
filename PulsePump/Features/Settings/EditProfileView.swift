import SwiftUI
import SwiftData

struct EditProfileView: View {
    @Bindable var user: User
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var weight: String
    @State private var height: String
    @State private var heightFeet: String
    @State private var heightInches: String
    /// Text the weight/height fields started with; unchanged fields are never written back, so
    /// opening and saving the form can't drift stored kg/cm through display rounding.
    private let initialWeight: String
    private let initialHeight: String
    @State private var age: String

    init(user: User) {
        self.user = user
        _name = State(initialValue: user.name)
        // User.weight is kg and User.height is cm; the fields show/accept the user's unit.
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
        Form {
            Section("Name") {
                TextField("Name", text: $name)
            }

            Section("Body Measurements") {
                HStack {
                    TextField("Weight", text: $weight)
                        .keyboardType(.decimalPad)
                    Text(user.unitPreference.lowercaseLabel)
                        .foregroundStyle(.secondary)
                }

                if user.unitPreference == .lbs {
                    HStack {
                        TextField("Feet", text: $heightFeet).keyboardType(.numberPad)
                        Text("ft").foregroundStyle(.secondary)
                        TextField("Inches", text: $heightInches).keyboardType(.numberPad)
                        Text("in").foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        TextField("Height", text: $height)
                            .keyboardType(.decimalPad)
                        Text("cm")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                    Text("years")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
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
               let ft = Double(heightFeet), ft > 0 {
                user.height = UnitPreference.cm(feet: ft, inches: Double(heightInches) ?? 0)
            }
        } else if height != initialHeight, let h = Double(height), h > 0 {
            user.height = h
        }
        if let a = Int(age) { user.age = a }
        user.updatedAt = Date()
    }
}
