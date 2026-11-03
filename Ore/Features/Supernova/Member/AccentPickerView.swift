import SwiftUI

/// The membership page's colours: the Stardust is always behind the header, wordmark and glass card (white text there, in both
/// appearances); everything below the tabs follows the appearance. From the design's per-theme tokens.
struct MemberPageTheme: Equatable {
    var dark: Bool

    private static let ink = Color(hex: "#151A21")
    var canvas: Color { dark ? Color(hex: "#1A1917") : Color(hex: "#F6F7F9") }
    var ink: Color { dark ? .white : Self.ink }
    var secondary: Color { dark ? .white.opacity(0.88) : Self.ink.opacity(0.72) }
    var muted: Color { dark ? .white.opacity(0.72) : Self.ink.opacity(0.55) }
    var ghost: Color { dark ? .white.opacity(0.45) : Self.ink.opacity(0.2) }
    var rule1: Color { dark ? .white.opacity(0.16) : Self.ink.opacity(0.08) }
    var rule2: Color { dark ? .white.opacity(0.32) : Self.ink.opacity(0.14) }
    var elevated: Color { dark ? .white.opacity(0.10) : Color(hex: "#ECEFF3") }
    var sunken: Color { dark ? .white.opacity(0.12) : Color(hex: "#E0E5EB") }
    /// Chips, the tab track and the ± buttons.
    var chip: Color { dark ? .white.opacity(0.12) : Self.ink.opacity(0.06) }
    var chipFocus: Color { dark ? .white.opacity(0.14) : Self.ink.opacity(0.10) }
    /// The hex field's background.
    var track: Color { dark ? .white.opacity(0.08) : .white.opacity(0.16) }
    var fieldError: Color { dark ? Color(red: 1, green: 217 / 255, blue: 210 / 255).opacity(0.9) : Color(hex: "#C0341A") }
    var fieldBorder: Color { dark ? .white.opacity(0.28) : Self.ink.opacity(0.2) }
}

private extension Color {
    init(h: Double, s: Double, l: Double) {
        let c = AccentMath.rgb(h: h, s: s, l: l)
        self.init(red: Double(c.r) / 255, green: Double(c.g) / 255, blue: Double(c.b) / 255)
    }
}

/// The Account tab's accent picker: a swatch and an editable hex, ADJUST (hue, shade and saturation strips with − / + buttons),
/// and the presets & recent row. Every change recolours the page Stardust, the More card Stardust and the app at once through
/// `AccentStore`. All the rules (curves, thresholds, palette) are `AccentMath` and the config's `picker` block.
struct AccentPickerView: View {
    var theme: MemberPageTheme

    private var store: AccentStore { .shared }
    private var picker: SupernovaMemberConfig.Picker { SupernovaMemberConfigStore.shared.current.picker }
    @State private var adjustOpen: Bool = {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "debugAccentAdjust")   // `-debugAccentAdjust 1` opens the sliders (screenshots)
        #else
        return false
        #endif
    }()
    @State private var hexDraft: String?
    @FocusState private var hexFocused: Bool

    private var pick: AccentPick { store.picked }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if adjustOpen {
                VStack(spacing: 16) {
                    AccentSliderRow(channel: .hue, label: "HUE", theme: theme)
                    AccentSliderRow(channel: .shade, label: "SHADE", theme: theme)
                    AccentSliderRow(channel: .saturation, label: "SATURATION", theme: theme)
                }
                .transition(.opacity)
            }
            presets
        }
        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 6)
    }

    // MARK: Swatch, hex, ADJUST

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8).fill(Color(hex: pick.hexString)).frame(width: 44, height: 44)
                .accessibilityIdentifier(AX.supernova.accentCurrent)
            VStack(alignment: .leading, spacing: 3) {
                hexField
                Text(store.pickedName).font(.spaceMono(8)).tracking(1.5).foregroundStyle(theme.muted)
            }
            Spacer(minLength: 0)
            Button { withAnimation(.easeInOut(duration: 0.25)) { adjustOpen.toggle() } } label: {
                HStack(spacing: 8) {
                    Text("ADJUST")
                    Text("▾").rotationEffect(.degrees(adjustOpen ? 180 : 0)).animation(.easeInOut(duration: 0.25), value: adjustOpen)
                }
                .font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(theme.ink)
                .padding(.horizontal, 12).frame(height: 44)
                .background(theme.chip).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PressOpacityStyle())
            .accessibilityIdentifier(AX.supernova.accentAdjust)
        }
    }

    private var hexBad: Bool { hexDraft != nil && AccentMath.normalizeHex(hexDraft ?? "") == nil }

    private var hexField: some View {
        TextField("", text: Binding(get: { hexDraft ?? pick.hexString }, set: hexEdited))
            .focused($hexFocused)
            .font(.spaceMono(14, weight: .bold)).tracking(1).foregroundStyle(theme.ink)
            .textInputAutocapitalization(.characters).autocorrectionDisabled().keyboardType(.asciiCapable).submitLabel(.done)
            .padding(.horizontal, 8).frame(width: 96, height: 32)
            .background(hexFocused ? theme.chipFocus : theme.track)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(hexBad ? theme.fieldError : theme.fieldBorder, lineWidth: 1))
            .padding(.leading, -8)
            .onSubmit(commitHex)
            .onChange(of: hexFocused) { _, focused in if !focused { commitHex() } }   // blur commits; an invalid draft reverts
            .onKeyPress(.escape) { hexDraft = nil; hexFocused = false; return .handled }
            .accessibilityIdentifier(AX.supernova.accentHex)
    }

    /// Typing applies live once six valid digits are there (three-digit shorthand applies when the field is committed).
    private func hexEdited(_ raw: String) {
        let text = String(raw.uppercased().prefix(7))
        hexDraft = text
        if text.replacingOccurrences(of: "#", with: "").count == 6, let hex = AccentMath.normalizeHex(text), let c = AccentMath.hsl(fromHex: hex) {
            store.set(AccentPick(h: c.h, s: c.s, l: c.l, hex: hex))
        }
    }

    private func commitHex() {
        if let draft = hexDraft, let hex = AccentMath.normalizeHex(draft), let c = AccentMath.hsl(fromHex: hex) {
            store.set(AccentPick(h: c.h, s: c.s, l: c.l, hex: hex))
        }
        hexDraft = nil
    }

    // MARK: Presets & recent

    private var presets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRESETS & RECENT").font(.spaceMono(8)).tracking(1.5).foregroundStyle(theme.muted)
            HStack(spacing: 0) {
                ForEach(Array(store.swatches.enumerated()), id: \.offset) { i, sw in
                    if i > 0 { Spacer(minLength: 4) }
                    Button {
                        hexDraft = nil
                        hexFocused = false
                        store.set(sw.pick)
                    } label: {
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 6).fill(Color(hex: sw.hex)).frame(width: 26, height: 26)
                            Capsule().fill(sw.hex == pick.hexString ? theme.ink : .clear).frame(width: 16, height: 2)
                        }
                        .padding(.vertical, 6).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(sw.name)
                    .accessibilityIdentifier(AX.supernova.accentSwatch(String(sw.hex.dropFirst())))
                    .accessibilityAddTraits(sw.hex == pick.hexString ? .isSelected : [])
                }
            }
        }
    }
}

// MARK: - A slider row

/// `[−] [strip] [+]` with the label and live value above. The strip: tap jumps, drag is relative (no jump from the thumb), and
/// a finger 60 pt (¼ speed) or 120 pt (1/10) away from the strip scrubs finely. − / + repeat while held, accelerating.
private struct AccentSliderRow: View {
    var channel: AccentMath.Channel
    var label: String
    var theme: MemberPageTheme

    private var store: AccentStore { .shared }
    private var picker: SupernovaMemberConfig.Picker { SupernovaMemberConfigStore.shared.current.picker }
    private var pick: AccentPick { store.picked }
    @State private var drag: (lastX: Double, value: Double)?

    private var value: Double {
        switch channel { case .hue: Double(pick.h); case .saturation: Double(pick.s); case .shade: Double(pick.l) }
    }
    private var fraction: Double {
        let r = AccentMath.range(channel)
        return (value - r.lowerBound) / (r.upperBound - r.lowerBound)
    }
    private var valueText: String { channel == .hue ? "\(pick.h)°" : "\(Int(value))%" }
    private var id: String { label.lowercased() }

    private var strip: LinearGradient {
        let h = Double(pick.h), s = Double(pick.s)
        switch channel {
        case .hue:
            return LinearGradient(colors: stride(from: 0.0, through: 360, by: 60).map { Color(h: $0, s: 90, l: 55) }, startPoint: .leading, endPoint: .trailing)
        case .shade:
            return LinearGradient(colors: [.black, Color(h: h, s: s, l: 50), .white], startPoint: .leading, endPoint: .trailing)
        case .saturation:
            let l = Double(max(20, min(80, pick.l)))
            return LinearGradient(colors: [Color(h: h, s: 0, l: l), Color(h: h, s: 100, l: l)], startPoint: .leading, endPoint: .trailing)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label).foregroundStyle(theme.muted)
                Spacer(minLength: 0)
                Text(valueText).foregroundStyle(theme.secondary)
            }
            .font(.spaceMono(8)).tracking(1.5)
            HStack(spacing: 8) {
                StepButton(symbol: "−", channel: channel, direction: -1, theme: theme).accessibilityIdentifier(AX.supernova.accentStep(id, -1))
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8).fill(strip)
                        let x = max(5, min(g.size.width - 5, fraction * g.size.width))
                        RoundedRectangle(cornerRadius: 4).fill(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: "#151A21").opacity(0.55), lineWidth: 1.5))
                            .frame(width: 10, height: g.size.height + 8)
                            .position(x: x, y: g.size.height / 2)
                            .allowsHitTesting(false)
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { d in dragged(d, width: g.size.width, height: g.size.height) }
                        .onEnded { _ in drag = nil })
                }
                .frame(height: 32)
                .accessibilityElement()
                .accessibilityLabel(label)
                .accessibilityValue(valueText)
                .accessibilityIdentifier(AX.supernova.accentStrip(id))
                .accessibilityAdjustableAction { dir in
                    store.set(AccentMath.nudged(channel, by: dir == .increment ? 1 : -1, in: pick, rule: picker.huePatch))
                }
                StepButton(symbol: "+", channel: channel, direction: 1, theme: theme).accessibilityIdentifier(AX.supernova.accentStep(id, 1))
            }
        }
    }

    private func dragged(_ d: DragGesture.Value, width: Double, height: Double) {
        let r = AccentMath.range(channel), span = r.upperBound - r.lowerBound
        let x = min(max(0, d.location.x), width)
        var current = drag
        if current == nil {
            // Touching the thumb drags from where it is; anywhere else jumps there.
            let thumbX = fraction * width
            let start = abs(d.startLocation.x - thumbX) <= 14 ? value : r.lowerBound + min(max(0, d.startLocation.x / max(1, width)), 1) * span
            current = (lastX: Double(d.startLocation.x), value: start)
        }
        guard var state = current else { return }
        let distance = abs(d.location.y - height / 2)
        state.value = AccentMath.dragged(state.value, dx: x - min(max(0, state.lastX), width), width: width, channel: channel, distance: distance, curve: picker.fine)
        state.lastX = x
        drag = state
        store.set(AccentMath.setting(channel, to: state.value, in: pick, rule: picker.huePatch))
    }
}

/// A 44 pt − / + button: one step on a tap, repeating while held (after a delay, faster the longer it is held), stopping the
/// moment the finger lifts, is cancelled or slides off.
private struct StepButton: View {
    var symbol: String
    var channel: AccentMath.Channel
    var direction: Int
    var theme: MemberPageTheme

    @State private var holding: Task<Void, Never>?
    @State private var pressed = false
    private var picker: SupernovaMemberConfig.Picker { SupernovaMemberConfigStore.shared.current.picker }

    var body: some View {
        Text(symbol).font(.spaceMono(16, weight: .bold)).foregroundStyle(theme.ink)
            .frame(width: 44, height: 44)
            .background(theme.chip).clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(pressed ? 0.7 : 1)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { d in
                    let inside = CGRect(x: 0, y: 0, width: 44, height: 44).contains(d.location)
                    if !inside { stop() } else if holding == nil && !pressed { start() }
                }
                .onEnded { _ in stop() })
            .onDisappear { stop() }
    }

    private func nudge(_ n: Int) {
        let store = AccentStore.shared
        store.set(AccentMath.nudged(channel, by: n, in: store.picked, rule: picker.huePatch))
    }

    private func start() {
        pressed = true
        nudge(direction)
        let t0 = Date()
        let picker = picker
        holding = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(picker.holdDelayMs))
            while !Task.isCancelled {
                let seconds = Date().timeIntervalSince(t0)
                nudge(direction * AccentMath.holdStep(channel, seconds: seconds, picker: picker))
                try? await Task.sleep(for: .milliseconds(AccentMath.holdInterval(seconds: seconds, picker: picker)))
            }
        }
    }

    private func stop() {
        holding?.cancel()
        holding = nil
        pressed = false
    }
}
