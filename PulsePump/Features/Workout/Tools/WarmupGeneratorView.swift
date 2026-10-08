import SwiftUI

struct WarmupGeneratorView: View {
    @State private var workingWeight = ""
    @Environment(\.weightUnit) private var unit
    /// Everything on this screen is typed and shown in the user's unit; nothing is stored.
    @State private var barWeight: Double = 20
    @State private var warmupSteps = 4

    private var warmupSets: [(weight: Double, reps: Int)] {
        guard let working = parseDecimal(workingWeight), working > barWeight else { return [] }

        var sets: [(Double, Int)] = []

        // Always start with bar
        sets.append((barWeight, 10))

        let increments = warmupSteps - 1
        guard increments > 0 else { return sets }

        for i in 1...increments {
            let fraction = Double(i) / Double(increments + 1)
            let weight = barWeight + (working - barWeight) * fraction
            // Round to the nearest loadable jump: 2.5 kg / 5 lb
            let step = unit.stepperIncrement
            let rounded = (weight / step).rounded() * step
            let reps = max(3, 10 - (i * 2))
            if rounded > barWeight {
                sets.append((rounded, reps))
            }
        }

        return sets
    }

    var body: some View {
        List {
            Section("Working Set Weight") {
                HStack {
                    TextField("0", text: $workingWeight)
                        .keyboardType(.decimalPad)
                        .font(.title2.monospacedDigit())
                    Text(unit.lowercaseLabel)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Stepper("Warmup Sets: \(warmupSteps)", value: $warmupSteps, in: 2...6)

                Picker("Bar Weight", selection: $barWeight) {
                    Text("Olympic (\(unit == .kg ? "20 kg" : "45 lb"))").tag(unit == .kg ? 20.0 : 45.0)
                    Text("EZ Curl (\(unit == .kg ? "10 kg" : "25 lb"))").tag(unit == .kg ? 10.0 : 25.0)
                    Text("Trap Bar (\(unit == .kg ? "25 kg" : "55 lb"))").tag(unit == .kg ? 25.0 : 55.0)
                }
                .onChange(of: unit) { _, u in barWeight = u == .kg ? 20 : 45 }
                .onAppear { barWeight = unit == .kg ? 20 : 45 }
            }

            if !warmupSets.isEmpty {
                Section("Warmup Plan") {
                    ForEach(Array(warmupSets.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text("Set \(index + 1)")
                                .font(.mono(15))
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .leading)
                            Text("\(UnitPreference.trim(set.weight)) \(unit.lowercaseLabel)")
                                .font(.callout.monospacedDigit().weight(.medium))
                            Spacer()
                            Text("\(set.reps) reps")
                                .font(.mono(15))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Working Set")
                            .font(.mono(15, weight: .medium))
                            .foregroundStyle(Color.accentInk)
                        Spacer()
                        Text("\(workingWeight) \(unit.lowercaseLabel)")
                            .font(.callout.monospacedDigit().weight(.semibold))
                    }
                }
            }
        }
        .navigationTitle("Warmup Generator")
    }
}
