import SwiftUI

struct PlateCalculatorView: View {
    @State private var targetWeight = ""
    @State private var barWeight: Double = 20
    @State private var availablePlates: [Double] = {
        if let data = UserDefaults.standard.data(forKey: "customPlates"),
           let plates = try? JSONDecoder().decode([Double].self, from: data) {
            return plates
        }
        return [1.25, 2.5, 5, 10, 15, 20, 25]
    }()
    @State private var unit: UnitPreference = .kg
    @State private var showPlateConfig = false
    @State private var newPlateWeight = ""

    private var platesPerSide: [Double] {
        guard let target = parseDecimal(targetWeight), target > barWeight else { return [] }
        let perSide = (target - barWeight) / 2.0
        return calculatePlates(target: perSide, available: availablePlates.sorted(by: >))
    }

    private var achievableWeight: Double {
        barWeight + platesPerSide.reduce(0, +) * 2
    }

    var body: some View {
        List {
            Section("Target Weight") {
                HStack {
                    TextField("0", text: $targetWeight)
                        .keyboardType(.decimalPad)
                        .font(.title2.monospacedDigit())
                    Text(unit.abbreviation)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Bar") {
                Picker("Bar Weight", selection: $barWeight) {
                    Text("Olympic (20 kg)").tag(20.0)
                    Text("EZ Curl (10 kg)").tag(10.0)
                    Text("Trap Bar (25 kg)").tag(25.0)
                    Text("Women's (15 kg)").tag(15.0)
                }
            }

            if !platesPerSide.isEmpty {
                Section("Per Side") {
                    ForEach(Array(plateCounts.enumerated()), id: \.offset) { _, entry in
                        HStack {
                            Text("\(String(format: "%g", entry.plate)) \(unit.abbreviation)")
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
                        Text("\(String(format: "%g", achievableWeight)) \(unit.abbreviation)")
                            .font(.mono(16, weight: .medium))
                    }
                }
            }

            Section("Available Plates") {
                ForEach(availablePlates.sorted(), id: \.self) { plate in
                    Text("\(String(format: "%g", plate)) \(unit.abbreviation)")
                }
                .onDelete { indices in
                    let sorted = availablePlates.sorted()
                    let toRemove = indices.map { sorted[$0] }
                    availablePlates.removeAll { toRemove.contains($0) }
                    savePlates()
                }

                HStack {
                    TextField("Add plate", text: $newPlateWeight)
                        .keyboardType(.decimalPad)
                    Button("Add") {
                        if let weight = parseDecimal(newPlateWeight), weight > 0, !availablePlates.contains(weight) {
                            availablePlates.append(weight)
                            savePlates()
                            newPlateWeight = ""
                        }
                    }
                    .disabled(newPlateWeight.isEmpty)
                }
            }
        }
        .navigationTitle("Plate Calculator")
    }

    private func savePlates() {
        if let data = try? JSONEncoder().encode(availablePlates) {
            UserDefaults.standard.set(data, forKey: "customPlates")
        }
    }

    private var plateCounts: [(plate: Double, count: Int)] {
        var counts: [Double: Int] = [:]
        for plate in platesPerSide {
            counts[plate, default: 0] += 1
        }
        return counts.sorted { $0.key > $1.key }.map { (plate: $0.key, count: $0.value) }
    }

    private func calculatePlates(target: Double, available: [Double]) -> [Double] {
        var remaining = target
        var result: [Double] = []
        for plate in available {
            while remaining >= plate {
                result.append(plate)
                remaining -= plate
            }
        }
        return result
    }
}
