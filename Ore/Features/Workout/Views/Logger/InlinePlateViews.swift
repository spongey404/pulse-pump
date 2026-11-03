import SwiftUI

/// The plate calculator under the next unlogged set of a barbell exercise (Ore Logger 1a / 2d): `PLATES · 60 KG ▴ HIDE`. Open: EACH SIDE
/// kg, the whole bar drawn to scale (both sleeves, no text on the plates), TAKE OFF (red) / PUT ON (blue) tags against the previous set,
/// then the bar tiles BARBELL 20 · EZ 7.5 · TRAP 25 · SAFETY 32 · LIGHT 15.
struct LoggerPlateSection: View {
    let setNumber: Int
    /// This set's weight and the previous set's, both kg (nil = an empty bar).
    let kg: Double
    let previousKg: Double?
    @Binding var isOpen: Bool
    @Binding var barKg: Double
    let exerciseIndex: Int
    /// The tutorial spotlights the toggle, then the open calculator.
    var tutorial = false
    @Environment(\.weightUnit) private var unit

    private var plates: [PlateMath.Plate] { PlateMath.load(targetKg: kg, barKg: barKg, platesKg: PlateMath.storedPlatesKg(unit: unit), unit: unit).plates }
    private var previousPlates: [PlateMath.Plate] {
        guard let previousKg else { return [] }
        return PlateMath.load(targetKg: previousKg, barKg: barKg, platesKg: PlateMath.storedPlatesKg(unit: unit), unit: unit).plates
    }
    private var change: LoggerMath.PlateChange { LoggerMath.plateChange(from: previousPlates.map(\.display), to: plates.map(\.display)) }
    private var perSide: Double { max(0, (unit.display(kg) - unit.display(barKg)) / 2) }

    var body: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { isOpen.toggle() } } label: {
                HStack {
                    Text("PLATES · \(unit.number(kg)) \(unit.label)").font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    Spacer()
                    Text(isOpen ? "▴ HIDE" : "▾ SHOW").font(.spaceMono(8, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkSecondary)
                }
                .padding(.leading, 10).padding(.trailing, 12).frame(minHeight: 34).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier(AX.workout.platesToggle(ex: exerciseIndex, setNumber))
            .tutorialTarget("tutorial.plates-toggle", enabled: tutorial)
            if isOpen { openBody.tutorialTarget("tutorial.plates-view", enabled: tutorial) }
        }
        .background(Color.surf2)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .overlay(alignment: .leading) { Rectangle().fill(Color.accentInk).frame(width: 2) }
    }

    private var openBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                LoggerLabel(text: "EACH SIDE")
                Spacer()
                HStack(spacing: 4) {
                    Text(LoggerMath.trim(perSide)).font(.spaceMono(13, weight: .bold)).foregroundStyle(Color.inkPrimary)
                    Text(unit.label).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                }
            }
            bar.frame(height: 72)
            VStack(spacing: 0) {
                if !change.takeOff.isEmpty { changeRow("TAKE OFF", color: .signalDown, sizes: change.takeOff) }
                if !change.putOn.isEmpty { changeRow("PUT ON", color: .accentInk, sizes: change.putOn) }
                if change.none {
                    Text("SAME AS LAST SET · NOTHING TO CHANGE").font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading).overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                }
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            LoggerLabel(text: previousKg.map { "FROM SET \(String(format: "%02d", setNumber - 1)) · \(unit.number($0)) \(unit.label)" } ?? "FROM AN EMPTY BAR")
            barTiles
        }
        .padding(.leading, 10).padding(.trailing, 12).padding(.bottom, 12)
    }

    // MARK: Bar drawing

    private func plateView(_ p: PlateMath.Plate) -> some View {
        let tier = PlateMath.tier(forKg: p.kg), st = PlatePalette.style(tier), sz = PlatePalette.size(tier)
        return RoundedRectangle(cornerRadius: 3).fill(st.shape).frame(width: sz.width, height: sz.height)
            .overlay { if let b = st.border { RoundedRectangle(cornerRadius: 3).strokeBorder(b, lineWidth: 1) } }
    }

    private var bar: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 14, height: 8)
            HStack(spacing: 2) { ForEach(Array(plates.enumerated().reversed()), id: \.offset) { _, p in plateView(p) } }
            RoundedRectangle(cornerRadius: 1).fill(Color.inkSecondary).frame(width: 5, height: 20).padding(.horizontal, 1)
            Rectangle().fill(Color.gray.opacity(0.5)).frame(maxWidth: 110).frame(height: 8)
            RoundedRectangle(cornerRadius: 1).fill(Color.inkSecondary).frame(width: 5, height: 20).padding(.horizontal, 1)
            HStack(spacing: 2) { ForEach(Array(plates.enumerated()), id: \.offset) { _, p in plateView(p) } }
            Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 14, height: 8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement().accessibilityLabel("Bar loaded with \(unit.number(kg)) \(unit.label)")
    }

    private func changeRow(_ title: String, color: Color, sizes: [Double]) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title).font(.spaceMono(8, weight: .bold)).tracking(1.5).foregroundStyle(color).frame(width: 72, alignment: .leading)
            FlowLayout(spacing: 4) {
                ForEach(Array(sizes.enumerated()), id: \.offset) { _, size in PlateTag(label: LoggerMath.trim(size), kg: unit.kg(fromDisplay: size)) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 30).overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private var barTiles: some View {
        HStack(spacing: 4) {
            ForEach(PlateMath.barOptions, id: \.name) { bt in
                let bar = bt.weightKg(unit), on = PlateMath.sameBar(barKg, bar)
                Button { withAnimation(.easeInOut(duration: 0.15)) { barKg = bar } } label: {
                    VStack(spacing: 2) {
                        Text(bt.name).font(.spaceMono(9, weight: .bold)).tracking(0.8)
                        Text("\(UnitPreference.trim(unit == .kg ? bt.kgValue : bt.lbValue)) \(unit.label)").font(.spaceMono(8)).tracking(1).opacity(on ? 0.85 : 1)
                            .foregroundStyle(on ? Color.white : Color.inkMuted)
                    }
                    .foregroundStyle(on ? Color.white : Color.inkPrimary)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(on ? Color.oreAccent : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(on ? Color.oreAccent : Color.ruleStrong, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

extension Double {
    var clean: String { truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(self) }
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
