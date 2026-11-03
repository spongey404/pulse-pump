import SwiftUI

/// What the keypad is editing.
struct KeypadTarget: Equatable {
    var exerciseIndex: Int
    var setIndex: Int
    var field: LoggerField
}

/// The logger's keypad (Ore Logger 1a): flat, hairline-divided, a heavy ink rule on top. "EDITING KG" + DONE, a step strip
/// (−2.5 −1.25 +1.25 +2.5; reps −2 −1 +1 +2), keys 1–9 . 0 (wide) with ⌫ top right and a tall accent NEXT / LOG SET on the right.
/// RIR is a 0–5+ chip row instead of keys.
struct LoggerKeypad: View {
    let fieldTitle: String
    let field: LoggerField
    /// "NEXT REPS" / "LOG SET".
    let nextTitle: String
    let nextGlyph: String
    let stepLabels: [(label: String, delta: Double)]
    var selectedRir: Int?
    var onKey: (String) -> Void
    var onBackspace: () -> Void
    var onStep: (Double) -> Void
    var onRir: (Int) -> Void
    var onNext: () -> Void
    var onDone: () -> Void

    private let rowHeight: CGFloat = 46

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("EDITING \(fieldTitle)").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.accentInk)
                    .accessibilityIdentifier(AX.keypad.editing)
                Spacer()
                Button(action: onDone) {
                    Text("DONE").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.accentInk).padding(.vertical, 6).padding(.leading, 12)
                }
                .buttonStyle(.plain).accessibilityIdentifier(AX.keypad.done)
            }
            .padding(.horizontal, 16)

            if field == .rir { rirBody } else { numericBody }
        }
        .padding(.top, 10).padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background(Color.canvasBg.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Color.inkPrimary).frame(height: 2) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AX.keypad.root)
    }

    // MARK: Numbers

    private var numericBody: some View {
        VStack(spacing: 0) {
            // Step strip
            HStack(spacing: 1) {
                ForEach(Array(stepLabels.enumerated()), id: \.offset) { _, s in
                    Button { onStep(s.delta) } label: {
                        Text(s.label).font(.spaceMono(13, weight: .bold)).foregroundStyle(s.delta < 0 ? Color.inkSecondary : Color.inkPrimary)
                            .frame(maxWidth: .infinity).frame(height: 40).background(Color.canvasBg).contentShape(Rectangle())
                    }
                    .buttonStyle(KeyPressStyle())
                    .accessibilityIdentifier(AX.keypad.step(s.label))
                }
            }
            .background(Color.dsHairLine)
            .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

            // Keys
            HStack(spacing: 1) {
                Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                    GridRow { key("1"); key("2"); key("3") }
                    GridRow { key("4"); key("5"); key("6") }
                    GridRow { key("7"); key("8"); key("9") }
                    GridRow { key(".", enabled: field != .reps && field != .rir); key("0").gridCellColumns(2) }
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 1) {
                    Button(action: onBackspace) {
                        Text("⌫").font(.spaceMono(18, weight: .bold)).foregroundStyle(Color.inkSecondary)
                            .frame(maxWidth: .infinity).frame(height: rowHeight).background(Color.canvasBg).contentShape(Rectangle())
                    }
                    .buttonStyle(KeyPressStyle()).accessibilityIdentifier(AX.keypad.backspace).accessibilityLabel("Delete")
                    nextButton
                }
                .frame(width: 110)
            }
            .background(Color.dsHairLine)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            .padding(.top, 0)
        }
    }

    private func key(_ k: String, enabled: Bool = true) -> some View {
        Button { if enabled { onKey(k) } } label: {
            Text(k).font(.spaceMono(20, weight: .bold)).foregroundStyle(enabled ? Color.inkPrimary : Color.inkGhost)
                .frame(maxWidth: .infinity).frame(height: rowHeight).background(Color.canvasBg).contentShape(Rectangle())
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityIdentifier(AX.keypad.key(k == "." ? "dot" : k))
    }

    private var nextButton: some View {
        Button(action: onNext) {
            VStack(alignment: .leading, spacing: 2) {
                Spacer(minLength: 0)
                Text(nextGlyph).font(.archivo(22, weight: .black)).foregroundStyle(.white)
                Text(nextTitle).font(.archivo(13, weight: .black)).tracking(0.6).foregroundStyle(.white).multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 12).padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background { if nextGlyph == "✓" { AccentFill(priority: 10) } else { Color.oreAccent } }      // only LOG SET gets Stardust, NEXT is plain
            .contentShape(Rectangle())
        }
        .buttonStyle(PressOpacityButtonStyle())
        .frame(height: rowHeight * 3 + 2)
        .accessibilityIdentifier(AX.keypad.next)
    }

    // MARK: RIR

    private var rirBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REPS IN RESERVE · HOW MANY MORE YOU HAD LEFT").font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).padding(.horizontal, 16)
            HStack(spacing: 1) {
                ForEach(0..<6, id: \.self) { v in
                    Button { onRir(v) } label: {
                        Text(v == 5 ? "5+" : "\(v)").font(.spaceMono(18, weight: .bold))
                            .foregroundStyle(selectedRir == v ? Color.white : Color.inkPrimary)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(selectedRir == v ? Color.oreAccent : Color.surf).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier(AX.keypad.rir(v))
                }
            }
            .background(Color.dsHairLine)
            .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            Button(action: onNext) {
                HStack {
                    Text(nextTitle).font(.archivo(15, weight: .black)).tracking(0.6)
                    Spacer()
                    Text(nextGlyph).font(.archivo(20, weight: .black))
                }
                .foregroundStyle(.white).padding(.horizontal, 18).frame(height: 52).frame(maxWidth: .infinity)
                .background { if nextGlyph == "✓" { AccentFill(priority: 10) } else { Color.oreAccent } }.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(PressOpacityButtonStyle()).padding(.horizontal, 16).accessibilityIdentifier(AX.keypad.next)
        }
    }
}

struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.overlay(configuration.isPressed ? Color.surf : Color.clear)
    }
}

/// Typed digits for a field: pure so it is tested. `.` only for kg-like fields, one decimal point, six characters at most.
enum KeypadBuffer {
    static func apply(_ key: String, to buffer: String, allowsDecimal: Bool) -> String {
        if key == "⌫" { return String(buffer.dropLast()) }
        if key == "." {
            guard allowsDecimal, !buffer.contains(".") else { return buffer }
            return (buffer.isEmpty ? "0" : buffer) + "."
        }
        guard buffer.count < 6 else { return buffer }
        return buffer + key
    }

    /// The number the buffer means (nil while empty or just ".").
    static func value(_ buffer: String) -> Double? { buffer.isEmpty || buffer == "." ? nil : Double(buffer) }
}
