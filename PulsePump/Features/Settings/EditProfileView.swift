import SwiftUI
import SwiftData

struct EditProfileView: View {
    @Bindable var user: User
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var weight: String
    @State private var height: String
    @State private var age: String

    init(user: User) {
        self.user = user
        _name = State(initialValue: user.name)
        _weight = State(initialValue: user.weight > 0 ? String(format: "%g", user.weight) : "")
        _height = State(initialValue: user.height > 0 ? String(format: "%g", user.height) : "")
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
                    Text(user.unitPreference.abbreviation)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    TextField("Height", text: $height)
                        .keyboardType(.decimalPad)
                    Text("cm")
                        .foregroundStyle(.secondary)
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
        if let w = Double(weight) { user.weight = w; BodyweightLog.record(kg: w) }
        if let h = Double(height) { user.height = h }
        if let a = Int(age) { user.age = a }
        user.updatedAt = Date()
    }
}
