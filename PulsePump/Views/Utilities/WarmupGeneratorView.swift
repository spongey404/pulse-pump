import SwiftUI

struct WarmupGeneratorView: View {
    @State private var workingWeight = ""
    @State private var barWeight: Double = 20
    @State private var warmupSteps = 4
    @State private var unit: UnitPreference = .kg

    private var warmupSets: [(weight: Double, reps: Int)] {
        guard let working = Double(workingWeight), working > barWeight else { return [] }

        var sets: [(Double, Int)] = []

        // Always start with bar
        sets.append((barWeight, 10))

        let increments = warmupSteps - 1
        guard increments > 0 else { return sets }

        for i in 1...increments {
            let fraction = Double(i) / Double(increments + 1)
            let weight = barWeight + (working - barWeight) * fraction
            // Round to nearest 2.5
            let rounded = (weight / 2.5).rounded() * 2.5
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
                    Text(unit.abbreviation)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Stepper("Warmup Sets: \(warmupSteps)", value: $warmupSteps, in: 2...6)

                Picker("Bar Weight", selection: $barWeight) {
                    Text("Olympic (20 kg)").tag(20.0)
                    Text("EZ Curl (10 kg)").tag(10.0)
                    Text("Trap Bar (25 kg)").tag(25.0)
                }
            }

            if !warmupSets.isEmpty {
                Section("Warmup Plan") {
                    ForEach(Array(warmupSets.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text("Set \(index + 1)")
                                .font(.mono(15))
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .leading)
                            Text("\(String(format: "%g", set.weight)) \(unit.abbreviation)")
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
                            .foregroundStyle(Color.pumpAccent)
                        Spacer()
                        Text("\(workingWeight) \(unit.abbreviation)")
                            .font(.callout.monospacedDigit().weight(.semibold))
                    }
                }
            }
        }
        .navigationTitle("Warmup Generator")
    }
}
