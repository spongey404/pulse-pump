import SwiftUI
import SwiftData

struct InlinePlateView: View {
    let entry: ExerciseEntry
    let equipmentType: EquipmentType

    private var barWeight: Double { equipmentType == .ezBar ? 10.0 : 20.0 }

    private var availablePlates: [Double] {
        if let data = UserDefaults.standard.data(forKey: "customPlates"),
           let plates = try? JSONDecoder().decode([Double].self, from: data) { return plates }
        return [1.25, 2.5, 5, 10, 15, 20, 25]
    }

    private var currentWeight: Double? {
        let weights = entry.sets.compactMap { parseDecimal($0.weight) }.filter { $0 > 0 }
        return weights.last
    }

    private var platesPerSide: [(plate: Double, count: Int)] {
        guard let target = currentWeight, target > barWeight else { return [] }
        let perSide = (target - barWeight) / 2.0
        var remaining = perSide
        var counts: [Double: Int] = [:]
        for plate in availablePlates.sorted(by: >) {
            while remaining >= plate - 0.001 { counts[plate, default: 0] += 1; remaining -= plate }
        }
        return counts.sorted { $0.key > $1.key }.map { (plate: $0.key, count: $0.value) }
    }

    var body: some View {
        if let weight = currentWeight, weight > barWeight, !platesPerSide.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "scalemass").font(.mono(9)).foregroundStyle(Color.inkMuted)
                Text("PER SIDE:")
                    .font(Font.mono(9)).foregroundStyle(Color.inkMuted).tracking(0.5)
                ForEach(platesPerSide, id: \.plate) { plate, count in
                    plateChip(plate: plate, count: count)
                }
                Spacer()
            }
        }
    }

    private func plateChip(plate: Double, count: Int) -> some View {
        let col = plateColor(plate)
        return Text("\(String(format: "%g", plate))×\(count)")
            .font(Font.mono(10))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(col)
            .clipShape(Capsule())
    }

    private func plateColor(_ kg: Double) -> Color {
        switch kg {
        case 25:   return Color(hex: "#c0341a")
        case 20:   return Color(hex: "#1a5ca8")
        case 15:   return Color(hex: "#b8a200")
        case 10:   return Color(hex: "#1a7a1a")
        case 5:    return Color(hex: "#2a2a2a")
        case 2.5:  return Color(hex: "#888888")
        default:   return Color(hex: "#bbbbbb")
        }
    }
}

// MARK: - Inline Plate Calculator

struct InlinePlateCalculatorView: View {
    let targetWeight: Double
    @Binding var barWeight: Double

    private let plateSizes: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
    private let barTypes: [(name: String, sub: String, kg: Double)] = [
        ("BARBELL", "20KG", 20),
        ("OLY 15",  "15KG", 15),
        ("EZ",      "7.5KG", 7.5),
        ("TRAP",    "25KG", 25),
        ("SAFETY",  "32KG", 32),
    ]

    private var perSideStack: [Double] {
        let perSide = (targetWeight - barWeight) / 2
        guard perSide > 0 else { return [] }
        var remaining = perSide
        var stack: [Double] = []
        for p in plateSizes {
            while remaining >= p - 0.001 {
                stack.append(p)
                remaining = (remaining - p).rounded(toPlaces: 3)
            }
        }
        return stack
    }

    private var remainder: Double {
        let perSide = (targetWeight - barWeight) / 2
        guard perSide > 0 else { return 0 }
        var remaining = perSide
        for p in plateSizes {
            while remaining >= p - 0.001 { remaining = (remaining - p).rounded(toPlaces: 3) }
        }
        return remaining
    }

    private func plateColor(_ p: Double) -> (bg: Color, fg: Color) {
        switch p {
        case 25:   return (Color(hex: "#e51b1b"), .white)
        case 20:   return (Color(hex: "#1f4ea3"), .white)
        case 15:   return (Color(hex: "#c98a17"), .white)
        case 10:   return (Color(hex: "#1f8f5a"), .white)
        case 5:    return (Color(hex: "#1f1c19"), Color(hex: "#f0efeb"))
        case 2.5:  return (Color(hex: "#a3a39a"), Color(hex: "#1f1c19"))
        default:   return (Color(hex: "#d6d2c4"), Color(hex: "#1f1c19"))
        }
    }

    private func plateHeight(_ p: Double) -> CGFloat {
        32 + min(p, 25) * 0.9
    }

    private func plateWidth(_ p: Double) -> CGFloat {
        p >= 20 ? 9 : p >= 10 ? 7 : p >= 5 ? 6 : 5
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
                            Text(targetWeight.clean)
                                .font(.archivo(30, weight: .black))
                                .foregroundStyle(Color.inkPrimary)
                                .monospacedDigit()
                            Text("KG · BAR \(barWeight.clean)")
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
                            let c = plateColor(p)
                            Text(p.clean)
                                .font(.spaceMono(9, weight: .bold))
                                .foregroundStyle(c.fg)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(c.bg)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        if remainder > 0.01 {
                            Text("+\(String(format: "%.2f", remainder))KG OFF")
                                .font(.spaceMono(9))
                                .foregroundStyle(Color.accentInk)
                        }
                        Spacer()
                    }
                }

                // Bar type selector
                Rectangle().fill(Color.dsHairLine).frame(height: 1)
                HStack(spacing: 4) {
                    ForEach(barTypes, id: \.name) { bt in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { barWeight = bt.kg }
                        } label: {
                            VStack(spacing: 2) {
                                Text(bt.name)
                                    .font(.spaceMono(8, weight: .bold))
                                    .tracking(0.5)
                                Text(bt.sub)
                                    .font(.spaceMono(7))
                                    .opacity(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(barWeight == bt.kg ? Color.pumpAccent : Color.clear)
                            .foregroundStyle(barWeight == bt.kg ? Color.white : Color.inkMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(barWeight == bt.kg ? Color.clear : Color.dsHairLine, lineWidth: 1)
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
                    let c = plateColor(p)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(c.bg)
                        .frame(width: plateWidth(p), height: plateHeight(p))
                }
            }
            // Bar sleeve
            Rectangle()
                .fill(Color(hex: "#8a857c"))
                .frame(width: 60, height: 4)
            // Right plates
            HStack(alignment: .center, spacing: 1) {
                ForEach(Array(perSideStack.enumerated()), id: \.offset) { _, p in
                    let c = plateColor(p)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(c.bg)
                        .frame(width: plateWidth(p), height: plateHeight(p))
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
