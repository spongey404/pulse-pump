import Foundation
import SwiftUI

// MARK: - Units
//
// INVARIANT: everything stored or synced is kg (User.weight, SetLog.weight, BarConfig.weightKg,
// EquipmentProfile.availablePlates, bodyweight log, widget snapshot values, feed payloads, challenge
// values). Height is cm. `UnitPreference` (the user's choice) only changes how values are DISPLAYED
// and how typed input is interpreted. Convert at the UI edge, exactly once:
//   display: unit.display(kg)  /  unit.format(kg)      input: unit.kg(fromDisplay: x)  /  unit.parseKg(text)
// PumpShared is compiled into both the app and the widget extension so both label units the same way.

enum UnitPreference: String, Codable, CaseIterable, Identifiable {
    case kg
    case lbs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kg: "Kilograms (kg)"
        case .lbs: "Pounds (lbs)"
        }
    }

    var abbreviation: String { rawValue }

    /// Exact international pound.
    static let kgPerLb = 0.45359237

    /// UserDefaults key mirroring the signed-in user's preference, for code with no SwiftData access
    /// (services). Written by `RootView`; the User model stays the source of truth.
    static let defaultsKey = "weightUnit"

    /// Preference mirrored into UserDefaults (defaults to kg).
    static var current: UnitPreference {
        get { UnitPreference(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .kg }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }

    // MARK: Labels

    /// "KG" / "LB" (singular, as the design shows it next to numbers).
    var label: String { self == .kg ? "KG" : "LB" }
    var lowercaseLabel: String { self == .kg ? "kg" : "lb" }

    // MARK: Conversion

    /// kg -> value in this unit, unrounded.
    func display(_ kg: Double) -> Double { self == .kg ? kg : kg / Self.kgPerLb }

    /// Value typed in this unit -> kg (unrounded; keeping full precision avoids drift on round trips).
    func kg(fromDisplay value: Double) -> Double { self == .kg ? value : value * Self.kgPerLb }

    /// Smallest increment shown in summaries: kg are typed exactly so 0.01 only trims float noise;
    /// lb are mostly conversions of stored kg, so they snap to the nearest 0.5 lb (100 kg -> 220.5 LB).
    var displayStep: Double { self == .kg ? 0.01 : 0.5 }

    /// Display value rounded to the unit's increment (kg 0.01, lb 0.5).
    func roundedDisplay(_ kg: Double) -> Double {
        (display(kg) / displayStep).rounded() * displayStep
    }

    /// Default +/- stepper increment for a set weight field: 2.5 kg / 5 lb.
    var stepperIncrement: Double { self == .kg ? 2.5 : 5 }

    // MARK: Formatting

    /// Number only, trimmed: "82.5", "182", "0.25".
    func number(_ kg: Double) -> String { Self.trim(roundedDisplay(kg)) }

    /// "82.5 KG" / "182 LB".
    func format(_ kg: Double) -> String { "\(number(kg)) \(label)" }

    /// "82.5KG" without the space (tight chips).
    func formatTight(_ kg: Double) -> String { "\(number(kg))\(label)" }

    /// Signed delta, e.g. "+2.5 KG".
    func formatDelta(_ kg: Double) -> String {
        "\(kg < 0 ? "-" : "+")\(Self.trim(roundedDisplay(abs(kg)))) \(label)"
    }

    /// Volume-style total: whole numbers in this unit, thousands separated ("12,340").
    func volume(_ kg: Double) -> String { Self.grouped(display(kg).rounded()) }
    func formatVolume(_ kg: Double) -> String { "\(volume(kg)) \(label)" }

    /// Compact volume for tight tiles: "850", "13.4K".
    func compactVolume(_ kg: Double) -> String {
        let v = display(kg)
        return v >= 1000 ? String(format: "%.1fK", v / 1000) : "\(Int(v.rounded()))"
    }

    /// Text to prefill an editable field with (no unit label): exact to 2 decimals, never snapped,
    /// so opening and re-saving a field can't change the stored value.
    func inputText(_ kg: Double) -> String { Self.trim(display(kg)) }

    // MARK: Text fields holding kg strings
    //
    // Workout logging keeps set weights as kg strings internally (SetEntry.weight); the field the
    // user types in shows the display unit. These two map between them; kg mode is the identity.

    /// kg string -> text for a field in this unit ("" stays "").
    func displayText(kgString: String) -> String {
        guard self == .lbs, let kg = Double(kgString) else { return kgString }
        return Self.trim(display(kg))
    }

    /// Text typed in this unit -> kg string. Unparsable text (e.g. "12.") is passed through so
    /// typing isn't interrupted; lbs values keep 4 decimals of kg.
    func kgString(displayText: String) -> String {
        guard self == .lbs else { return displayText }
        let t = displayText.replacingOccurrences(of: ",", with: ".")
        guard let v = Double(t) else { return displayText }
        var s = String(format: "%.4f", kg(fromDisplay: v))
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    /// Parse a typed value in this unit (accepts "," decimal separator) into kg. nil if not a number.
    func parseKg(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let v = Double(t), v.isFinite else { return nil }
        return kg(fromDisplay: v)
    }

    /// Compact ("82.5") number string with at most 2 decimals.
    static func trim(_ v: Double) -> String {
        if v == v.rounded() { return String(Int(v)) }
        var s = String(format: "%.2f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }   // 224.999999 formats as "225.00"
        return s
    }

    static func grouped(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: v)) ?? String(Int(v))
    }

    // MARK: Plates and bars (physical objects, so real sets differ per unit)

    /// Plates a gym in this unit typically has, as KG for storage. Lb plates are converted exactly
    /// (45 lb = 20.4117 kg), so the plate calculator in lbs mode loads 45/35/25/10/5/2.5 lb plates.
    var defaultPlatesKg: [Double] {
        switch self {
        case .kg: [1.25, 2.5, 5, 10, 15, 20, 25]
        case .lbs: [2.5, 5, 10, 25, 35, 45].map { $0 * Self.kgPerLb }
        }
    }

    /// Olympic bar in this unit's numbers (20 kg / 45 lb), as kg.
    var olympicBarKg: Double { self == .kg ? 20 : 45 * Self.kgPerLb }

    // MARK: Height (cm stored)

    static func cm(feet: Double, inches: Double) -> Double { (feet * 12 + inches) * 2.54 }

    static func feetInches(fromCm cm: Double) -> (feet: Int, inches: Int) {
        let total = Int((cm / 2.54).rounded())
        return (total / 12, total % 12)
    }

    /// "180 CM" (kg users) or 5'11" (lbs users).
    func formatHeight(cm: Double) -> String {
        if self == .kg { return "\(Int(cm.rounded())) CM" }
        let (f, i) = Self.feetInches(fromCm: cm)
        return "\(f)'\(i)\""
    }
}

typealias WeightUnit = UnitPreference

// MARK: - Environment

private struct WeightUnitKey: EnvironmentKey {
    static let defaultValue: UnitPreference = .kg
}

extension EnvironmentValues {
    /// The user's weight display unit. Injected once at the root; views read it instead of fetching the User.
    var weightUnit: UnitPreference {
        get { self[WeightUnitKey.self] }
        set { self[WeightUnitKey.self] = newValue }
    }
}
