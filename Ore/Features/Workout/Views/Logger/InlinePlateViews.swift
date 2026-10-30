import SwiftUI
import SwiftData

struct InlinePlateView: View {
    let entry: ExerciseEntry
    let equipmentType: EquipmentType
    @Environment(\.weightUnit) private var unit

    /// Bar in kg (20 kg / 45 lb Olympic, EZ 10 kg / 15 lb nominal).
    private var barKg: Double { equipmentType == .ezBar ? unit.kg(fromDisplay: unit == .kg ? 10 : 15) : unit.olympicBarKg }

    private var currentWeightKg: Double? {
        let weights = entry.sets.compactMap { parseDecimal($0.weight) }.filter { $0 > 0 }   // SetEntry.weight is kg
        return weights.last
    }

    private var load: PlateMath.Load? {
        guard let target = currentWeightKg, target > barKg else { return nil }
        return PlateMath.load(targetKg: target, barKg: barKg, platesKg: PlateMath.storedPlatesKg(unit: unit), unit: unit)
    }

    var body: some View {
        if let load, !load.plates.isEmpty {
            let counts = Dictionary(grouping: load.plates, by: \.display).sorted { $0.key > $1.key }
            HStack(spacing: 6) {
                Image(systemName: "scalemass").font(.mono(9)).foregroundStyle(Color.inkMuted)
                Text("PER SIDE:")
                    .font(Font.mono(9)).foregroundStyle(Color.inkMuted).tracking(0.5)
                ForEach(counts, id: \.key) { size, plates in
                    plateChip(plate: plates[0], count: plates.count, size: size)
                }
                Spacer()
            }
        }
    }

    private func plateChip(plate: PlateMath.Plate, count: Int, size: Double) -> some View {
        Text("\(UnitPreference.trim(size))×\(count)")
            .font(Font.mono(10))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(plateColor(plate.kg))
            .clipShape(Capsule())
    }

    private func plateColor(_ kg: Double) -> Color {
        switch PlateMath.tier(forKg: kg) {
        case .red:    return Color(hex: "#c0341a")
        case .blue:   return Color(hex: "#1a5ca8")
        case .yellow: return Color(hex: "#b8a200")
        case .green:  return Color(hex: "#1a7a1a")
        case .black:  return Color(hex: "#2a2a2a")
        case .grey:   return Color(hex: "#888888")
        case .light:  return Color(hex: "#bbbbbb")
        }
    }
}

// MARK: - Inline Plate Calculator

struct InlinePlateCalculatorView: View {
    /// Both in kg (stored); everything shown and loaded is in the user's unit.
    let targetWeight: Double
    @Binding var barWeight: Double
    @Environment(\.weightUnit) private var unit

    private var load: PlateMath.Load {
        PlateMath.load(targetKg: targetWeight, barKg: barWeight,
                       platesKg: PlateMath.storedPlatesKg(unit: unit), unit: unit)
    }
    private var perSideStack: [PlateMath.Plate] { load.plates }
    private var remainder: Double { load.remainder }

    private func plateColor(_ kg: Double) -> (bg: Color, fg: Color) {
        switch PlateMath.tier(forKg: kg) {
        case .red:    return (Color(hex: "#e51b1b"), .white)
        case .blue:   return (Color(hex: "#1f4ea3"), .white)
        case .yellow: return (Color(hex: "#c98a17"), .white)
        case .green:  return (Color(hex: "#1f8f5a"), .white)
        case .black:  return (Color(hex: "#1f1c19"), Color(hex: "#f0efeb"))
        case .grey:   return (Color(hex: "#a3a39a"), Color(hex: "#1f1c19"))
        case .light:  return (Color(hex: "#d6d2c4"), Color(hex: "#1f1c19"))
        }
    }

    private func plateHeight(_ kg: Double) -> CGFloat {
        32 + min(kg, 25) * 0.9
    }

    private func plateWidth(_ kg: Double) -> CGFloat {
        kg >= 18 ? 9 : kg >= 9 ? 7 : kg >= 4.5 ? 6 : 5
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                // Header row
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PLATE CALCULATOR")
                            .font(.spaceMono(9))
                            .tracking(1.2)
                            .foregroundStyle(Color.inkMuted)
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(unit.number(targetWeight))
                                .font(.archivo(30, weight: .black))
                                .foregroundStyle(Color.inkPrimary)
                                .monospacedDigit()
                            Text("\(unit.label) · BAR \(unit.number(barWeight))")
                                .font(.spaceMono(10))
                                .foregroundStyle(Color.inkMuted)
                        }
                    }
                }

                // Visual plate bar
                plateBarView

                // Plate chips
                if perSideStack.isEmpty {
                    Text("BAR ONLY")
                        .font(.spaceMono(10))
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 6) {
                        Spacer()
                        ForEach(Array(perSideStack.enumerated()), id: \.offset) { _, p in
                            let c = plateColor(p.kg)
                            Text(UnitPreference.trim(p.display))
                                .font(.spaceMono(9, weight: .bold))
                                .foregroundStyle(c.fg)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(c.bg)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        if remainder > 0.01 {
                            Text("+\(UnitPreference.trim(remainder))\(unit.label) OFF")
                                .font(.spaceMono(9))
                                .foregroundStyle(Color.accentInk)
                        }
                        Spacer()
                    }
                }

                // Bar type selector
                Rectangle().fill(Color.dsHairLine).frame(height: 1)
                HStack(spacing: 4) {
                    ForEach(PlateMath.barOptions, id: \.name) { bt in
                        let bar = bt.weightKg(unit)
                        let selected = PlateMath.sameBar(barWeight, bar)
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { barWeight = bar }
                        } label: {
                            VStack(spacing: 2) {
                                Text(bt.name)
                                    .font(.spaceMono(8, weight: .bold))
                                    .tracking(0.5)
                                Text(bt.label(unit))
                                    .font(.spaceMono(7))
                                    .opacity(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(selected ? Color.oreAccent : Color.clear)
                            .foregroundStyle(selected ? Color.white : Color.inkMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(selected ? Color.clear : Color.dsHairLine, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.95))
                    }
                }
                .padding(.top, 4)
            }
            .padding(12)
        }
    }

    private var plateBarView: some View {
        HStack(spacing: 0) {
            Spacer()
            // Left plates (reversed)
            HStack(alignment: .center, spacing: 1) {
                ForEach(Array(perSideStack.reversed().enumerated()), id: \.offset) { _, p in
                    let c = plateColor(p.kg)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(c.bg)
                        .frame(width: plateWidth(p.kg), height: plateHeight(p.kg))
                }
            }
            // Bar sleeve
            Rectangle()
                .fill(Color(hex: "#8a857c"))
                .frame(width: 60, height: 4)
            // Right plates
            HStack(alignment: .center, spacing: 1) {
                ForEach(Array(perSideStack.enumerated()), id: \.offset) { _, p in
                    let c = plateColor(p.kg)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(c.bg)
                        .frame(width: plateWidth(p.kg), height: plateHeight(p.kg))
                }
            }
            Spacer()
        }
        .frame(height: 64)
    }
}

extension Double {
    var clean: String { truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(self) }
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

// MARK: - SetRowView (legacy alias kept for build compatibility)
