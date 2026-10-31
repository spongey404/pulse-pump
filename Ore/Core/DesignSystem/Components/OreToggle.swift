import SwiftUI

/// Every number of the Ore toggle (design "Ore Toggle"): sizes, colours, durations, the knob's star and the Stardust settings.
/// `Resources/oreToggle.config.json` is the shared source (Android reads the same file); `fallback` must equal it (a test checks).
struct OreToggleConfig: Codable, Equatable {
    struct Track: Codable, Equatable { var width: Double, height: Double, radius: Double, border: Double }
    struct Knob: Codable, Equatable { var size: Double, radius: Double, inset: Double, travel: Double }
    /// [r 0–255, g, b, alpha 0–1]
    struct Scheme: Codable, Equatable { var offTrack: [Double], offBorder: [Double], offKnob: [Double] }
    struct Star: Codable, Equatable { var path: String, size: Double, colorHex: String }
    struct Fx: Codable, Equatable { var density: Double, gold: Double, sparkle: Double, fps: Int }
    struct Row: Codable, Equatable { var padV: Double, padH: Double, gapV: Double, gapH: Double, descriptionMaxWidth: Double }

    var track: Track
    var knob: Knob
    var minRowHeight: Double
    var durationMs: Double
    var disabledOpacity: Double
    var light: Scheme
    var dark: Scheme
    var onKnob: [Double]
    var star: Star
    var fx: Fx
    var row: Row

    static let fallback = OreToggleConfig(
        track: .init(width: 56, height: 32, radius: 8, border: 1),
        knob: .init(size: 24, radius: 6, inset: 3, travel: 24),
        minRowHeight: 44, durationMs: 250, disabledOpacity: 0.4,
        light: .init(offTrack: [224, 229, 235, 1], offBorder: [21, 26, 33, 0.14], offKnob: [255, 255, 255, 1]),
        dark: .init(offTrack: [255, 255, 255, 0.12], offBorder: [255, 255, 255, 0.16], offKnob: [255, 255, 255, 0.55]),
        onKnob: [255, 255, 255, 1],
        star: .init(path: "M12 0C13 8 16 11 24 12C16 13 13 16 12 24C11 16 8 13 0 12C8 11 11 8 12 0Z", size: 12, colorHex: "#FFC83D"),
        fx: .init(density: 1600, gold: 0.4, sparkle: 0.55, fps: 30),
        row: .init(padV: 14, padH: 16, gapV: 6, gapH: 16, descriptionMaxWidth: 280))

    static let shared: OreToggleConfig = {
        if let url = Bundle.main.url(forResource: "oreToggle.config", withExtension: "json"),
           let data = try? Data(contentsOf: url), let c = try? JSONDecoder().decode(OreToggleConfig.self, from: data) { return c }
        return .fallback
    }()

    static func color(_ c: [Double]) -> Color {
        guard c.count == 4 else { return .clear }
        return Color(.sRGB, red: c[0] / 255, green: c[1] / 255, blue: c[2] / 255, opacity: c[3])
    }
}

/// The switch itself, drawn only (no gesture): a 56 × 32 rounded rectangle with a 24 × 24 knob that slides 24 pt. ON is the accent
/// colour; for a Supernova member with Stardust buttons on, an ON switch also has Stardust in the track and a gold star on the
/// knob. No spring, no bounce: 250 ms ease-in-out for the knob, the colours and the Stardust; Reduce Motion makes it instant.
struct OreToggleSwitch: View {
    var isOn: Bool
    var disabled = false

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The Stardust stays mounted while it fades out, then goes (it is mounted only while ON with Stardust).
    @State private var fxMounted = false
    @State private var fxVisible = false

    private var cfg: OreToggleConfig { .shared }
    private var Stardust: Bool { AccentStore.shared.stardustEnabled }
    private var ease: Animation? { reduceMotion ? nil : .easeInOut(duration: cfg.durationMs / 1000) }

    var body: some View {
        let on = isOn
        let s = scheme == .dark ? cfg.dark : cfg.light
        let t = cfg.track, k = cfg.knob
        let wantFx = on && Stardust
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: t.radius, style: .continuous)
                .fill(on ? Color.oreAccent : OreToggleConfig.color(s.offTrack))
            if fxMounted {
                StardustView(variant: "toggle", budget: .more,
                              overrides: StardustParams.Overrides(palette: AccentStore.shared.starPalette, density: cfg.fx.density,
                                                                   gold: cfg.fx.gold, sparkle: cfg.fx.sparkle, fps: cfg.fx.fps))
                    .opacity(fxVisible ? 1 : 0)
                    .allowsHitTesting(false)
            }
            RoundedRectangle(cornerRadius: t.radius, style: .continuous)
                .strokeBorder(on ? Color.clear : OreToggleConfig.color(s.offBorder), lineWidth: t.border)
            RoundedRectangle(cornerRadius: k.radius, style: .continuous)
                .fill(on ? OreToggleConfig.color(cfg.onKnob) : OreToggleConfig.color(s.offKnob))
                .frame(width: k.size, height: k.size)
                .overlay {
                    FourPointStar().fill(Color(hex: cfg.star.colorHex))
                        .frame(width: cfg.star.size, height: cfg.star.size)
                        .opacity(fxVisible ? 1 : 0)
                }
                // The knob sits `inset` inside the border (the design's absolute `top/left: 3px` is inside it).
                .offset(x: t.border + k.inset + (on ? k.travel : 0), y: t.border + k.inset)
        }
        .frame(width: t.width, height: t.height)
        .clipShape(RoundedRectangle(cornerRadius: t.radius, style: .continuous))
        .animation(ease, value: on)
        .animation(ease, value: fxVisible)
        .opacity(disabled ? cfg.disabledOpacity : 1)
        .onAppear { fxMounted = wantFx; fxVisible = wantFx }
        .onChange(of: wantFx) { _, want in
            if want {
                fxMounted = true
                DispatchQueue.main.async { fxVisible = true }   // one frame after mounting, so the fade-in runs
            } else {
                fxVisible = false
                DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : cfg.durationMs / 1000)) { if !fxVisible { fxMounted = false } }
            }
        }
        .onChange(of: on) { _, _ in if !disabled { UISelectionFeedbackGenerator().selectionChanged() } }
    }
}

/// A tappable Ore toggle: the track is the hit target (at least 44 pt tall), VoiceOver reads it as a switch.
struct OreToggle: View {
    @Binding var isOn: Bool
    var disabled = false
    var accessibilityLabel: String

    var body: some View {
        OreToggleSwitch(isOn: isOn, disabled: disabled)
            .frame(minHeight: OreToggleConfig.shared.minRowHeight)
            .contentShape(Rectangle())
            .onTapGesture { if !disabled { isOn.toggle() } }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityAddTraits(.isToggle)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { if !disabled { isOn.toggle() } }
    }
}

/// The settings row used wherever a toggle sits in a list: label left, switch right, an optional description under both, a
/// hairline below. The whole row is the hit target.
struct OreToggleRow: View {
    var label: String
    var description: String? = nil
    @Binding var isOn: Bool
    var disabled = false
    var identifier: String? = nil
    /// The hairline below the row (off when the row sits inside a card).
    var divider = true

    var body: some View {
        let r = OreToggleConfig.shared.row
        Button { if !disabled { isOn.toggle() } } label: {
            VStack(alignment: .leading, spacing: r.gapV) {
                HStack(spacing: r.gapH) {
                    Text(label).font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    OreToggleSwitch(isOn: isOn, disabled: disabled)
                }
                if let description {
                    Text(description).font(.archivo(13)).foregroundStyle(Color.inkMuted)
                        .cssLineHeight(fontName: "Archivo-Regular", size: 13, multiple: 1.4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: r.descriptionMaxWidth, alignment: .leading)
                }
            }
            .padding(.vertical, r.padV).padding(.horizontal, r.padH)
            .frame(minHeight: OreToggleConfig.shared.minRowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { if divider { Rectangle().fill(Color.dsHairLine).frame(height: 1) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
        .accessibilityHint(description ?? "")
        .accessibilityIdentifier(identifier ?? AX.row(label))
    }
}
