import Foundation

/// Plate loading maths, done in the user's DISPLAY unit so a lbs user gets real lb plates
/// (45/35/25/10/5/2.5) and an exact remainder, while every input and stored value stays kg.
///
/// Plate sets are stored in kg (`EquipmentProfile.availablePlates`, the quick-calculator "customPlates"
/// defaults). A lb plate is its exact kg equivalent (45 lb = 20.4117 kg) and is mapped back to its
/// nominal lb number (rounded to 0.01) for loading and labels.
enum PlateMath {
    struct Plate: Equatable {
        /// Nominal size in the display unit (45 for a 45 lb plate).
        var display: Double
        /// Same plate in kg (what is stored).
        var kg: Double
    }

    struct Load: Equatable {
        /// Plates for ONE side, heaviest first.
        var plates: [Plate]
        /// Per-side weight the plate set can't make up, in the display unit (0 when exact).
        var remainder: Double
    }

    static func nominal(_ kg: Double, unit: UnitPreference) -> Double {
        (unit.display(kg) * 100).rounded() / 100
    }

    /// Plates per side to reach `targetKg` on a `barKg` bar using `platesKg` (any order).
    static func load(targetKg: Double, barKg: Double, platesKg: [Double], unit: UnitPreference) -> Load {
        let perSide = (nominal(targetKg, unit: unit) - nominal(barKg, unit: unit)) / 2
        guard perSide > 0.001 else { return Load(plates: [], remainder: 0) }
        let sizes = Set(platesKg.filter { $0 > 0 }.map { nominal($0, unit: unit) }).sorted(by: >)
        var remaining = perSide
        var plates: [Plate] = []
        for size in sizes {
            while remaining >= size - 0.001 {
                plates.append(Plate(display: size, kg: unit.kg(fromDisplay: size)))
                remaining = ((remaining - size) * 1000).rounded() / 1000
            }
        }
        return Load(plates: plates, remainder: max(0, remaining) < 0.005 ? 0 : remaining)
    }

    /// Bars offered in the inline calculator: nominal number in each unit (a 45 lb bar is not 20 kg).
    struct BarOption: Equatable {
        var name: String
        var kgValue: Double
        var lbValue: Double
        func weightKg(_ unit: UnitPreference) -> Double { unit == .kg ? kgValue : lbValue * UnitPreference.kgPerLb }
        func label(_ unit: UnitPreference) -> String {
            UnitPreference.trim(unit == .kg ? kgValue : lbValue) + unit.label
        }
    }

    static let barOptions: [BarOption] = [
        BarOption(name: "BARBELL", kgValue: 20, lbValue: 45),
        BarOption(name: "EZ", kgValue: 7.5, lbValue: 15),
        BarOption(name: "TRAP", kgValue: 25, lbValue: 55),
        BarOption(name: "SAFETY", kgValue: 32, lbValue: 65),
        BarOption(name: "LIGHT", kgValue: 15, lbValue: 35),
    ]

    /// Equality for bar weights stored as kg doubles.
    static func sameBar(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }

    // MARK: Persisted plate set for the quick calculators (kg)

    /// Per-unit key so a lbs user's lb plate set doesn't overwrite the kg set ("customPlates" kept for kg).
    static func platesKey(_ unit: UnitPreference) -> String { unit == .kg ? "customPlates" : "customPlatesLbs" }

    static func storedPlatesKg(unit: UnitPreference, defaults: UserDefaults = .standard) -> [Double] {
        if let data = defaults.data(forKey: platesKey(unit)),
           let plates = try? JSONDecoder().decode([Double].self, from: data), !plates.isEmpty { return plates }
        return unit.defaultPlatesKg
    }

    static func savePlatesKg(_ plates: [Double], unit: UnitPreference, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(plates) { defaults.set(data, forKey: platesKey(unit)) }
    }

    /// IPF colour by physical size (kg), shared by plate chips so lb plates colour like their kg twins:
    /// 25 red, 20 blue, 15 yellow, 10 green, 5 white, 2.5 black, 1.25 chrome.
    enum Tier { case red, blue, yellow, green, white, black, chrome }
    static func tier(forKg kg: Double) -> Tier {
        switch kg {
        case 24...: .red
        case 18..<24: .blue
        case 12..<18: .yellow
        case 9..<12: .green
        case 4.5..<9: .white
        case 2.2..<4.5: .black
        default: .chrome
        }
    }
}
