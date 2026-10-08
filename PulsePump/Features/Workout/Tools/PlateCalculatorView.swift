import SwiftUI

/// Standalone plate calculator. Input and display are in the user's unit (`\.weightUnit`); the maths goes
/// through `PlateMath` (kg internally, plates loaded in the display unit's real plate sizes).
struct PlateCalculatorView: View {
    @Environment(\.weightUnit) private var unit
    @State private var targetWeight = ""
    /// Bar in kg (stored convention); the picker shows its nominal size in the user's unit.
    @State private var barKg: Double = 20
    @State private var availablePlatesKg: [Double] = []
    @State private var showPlateConfig = false
    @State private var newPlateWeight = ""

    private var targetKg: Double? { unit.parseKg(targetWeight) }

    private var load: PlateMath.Load? {
        guard let target = targetKg, target > barKg else { return nil }
        return PlateMath.load(targetKg: target, barKg: barKg, platesKg: availablePlatesKg, unit: unit)
    }

    private var achievableKg: Double {
        barKg + (load?.plates.reduce(0) { $0 + $1.kg } ?? 0) * 2
    }

    var body: some View {
        List {
            Section("Target Weight") {
                HStack {
                    TextField("0", text: $targetWeight)
                        .keyboardType(.decimalPad)
                        .font(.title2.monospacedDigit())
                    Text(unit.lowercaseLabel)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Bar") {
                Picker("Bar Weight", selection: $barKg) {
                    ForEach(PlateMath.barOptions, id: \.name) { bar in
                        Text("\(bar.name.capitalized) (\(UnitPreference.trim(unit == .kg ? bar.kgValue : bar.lbValue)) \(unit.lowercaseLabel))")
                            .tag(bar.weightKg(unit))
                    }
                }
            }

            if let load, !load.plates.isEmpty {
                Section("Per Side") {
                    ForEach(plateCounts(load), id: \.size) { entry in
                        HStack {
                            Text("\(UnitPreference.trim(entry.size)) \(unit.lowercaseLabel)")
                                .font(.body.monospacedDigit())
                            Spacer()
                            Text("x \(entry.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Achievable Weight")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(unit.format(achievableKg))
                            .font(.mono(16, weight: .medium))
                    }
                }
            }

            Section("Available Plates") {
                ForEach(availablePlatesKg.sorted(), id: \.self) { plate in
                    Text("\(UnitPreference.trim(PlateMath.nominal(plate, unit: unit))) \(unit.lowercaseLabel)")
                }
                .onDelete { indices in
                    let sorted = availablePlatesKg.sorted()
                    let toRemove = indices.map { sorted[$0] }
                    availablePlatesKg.removeAll { toRemove.contains($0) }
                    savePlates()
                }

                HStack {
                    TextField("Add plate (\(unit.lowercaseLabel))", text: $newPlateWeight)
                        .keyboardType(.decimalPad)
                    Button("Add") {
                        // Typed in the display unit, stored as kg.
                        if let kg = unit.parseKg(newPlateWeight), kg > 0,
                           !availablePlatesKg.contains(where: { abs($0 - kg) < 0.001 }) {
                            availablePlatesKg.append(kg)
                            savePlates()
                            newPlateWeight = ""
                        }
                    }
                    .disabled(newPlateWeight.isEmpty)
                }
            }
        }
        .navigationTitle("Plate Calculator")
        .onAppear { reloadForUnit() }
        .onChange(of: unit) { _, _ in reloadForUnit() }
    }

    private func reloadForUnit() {
        availablePlatesKg = PlateMath.storedPlatesKg(unit: unit)
        barKg = unit.olympicBarKg
    }

    private func savePlates() {
        PlateMath.savePlatesKg(availablePlatesKg, unit: unit)
    }

    private func plateCounts(_ load: PlateMath.Load) -> [(size: Double, count: Int)] {
        Dictionary(grouping: load.plates, by: \.display)
            .map { (size: $0.key, count: $0.value.count) }
            .sorted { $0.size > $1.size }
    }
}
