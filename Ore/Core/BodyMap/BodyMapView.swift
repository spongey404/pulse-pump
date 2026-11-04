import SwiftUI

/// Drives one figure's clock and stars. A class so the Canvas closures can advance it without touching SwiftUI state.
@MainActor
final class BodyFigureRunner {
    let epoch = Date()
    /// When the current reveal started, in ms on this runner's clock.
    var t0 = 0.0
    var engine: BodyStardustEngine?
    var engineKey = ""

    func ms(_ date: Date) -> Double { date.timeIntervalSince(epoch) * 1000 }
    func restart() { t0 = ms(Date()); engine = nil }
}

/// One figure (front or back) in three stacked layers on the same 1640 × 2360 frame: the base (silhouette + heat fill), the member
/// Stardust clipped to each worked muscle, and the ink line work on top. Free users get no star layer at all.
struct BodyFigureView: View {
    let side: BodyMapSide
    /// 0–1 per artwork muscle id.
    var levels: [String: Double]
    /// The Stardust follows the figure's owner, not the viewer.
    var member = false
    /// The heat fill's colour for a member: the accent they chose (nil = Ore's blue from the config).
    var accentHex: String? = nil
    /// Changing it replays the reveal.
    var replay = 0
    var onTap: ((String) -> Void)? = nil

    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var runner = BodyFigureRunner()
    @State private var geometry: BodyFigureGeometry?
    @State private var revealDone = false
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var visible = false

    private var config: BodyMapConfig { BodyMapConfigStore.shared.current }
    private var colors: BodyMapConfig.Colors { scheme == .dark ? config.theme.dark : config.theme.light }
    private var still: Bool { reduceMotion }
    private var starsPaused: Bool { !visible || scenePhase != .active || lowPower || still }
    private var token: String { "\(replay)|\(accentHex ?? "")|\(levels.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: ","))" }

    private static func color(_ c: (r: Double, g: Double, b: Double)) -> Color { Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: 1) }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let k = size.width / BodyFigureGeometry.artSize.width
            ZStack {
                baseLayer(k: k)
                if member { starLayer(k: k) }
                inkLayer(k: k)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .onTapGesture { p in
                guard let onTap, let geometry, let m = geometry.muscle(at: CGPoint(x: p.x / k, y: p.y / k)) else { return }
                onTap(m.id)
            }
        }
        .aspectRatio(BodyFigureGeometry.artSize.width / BodyFigureGeometry.artSize.height, contentMode: .fit)
        .task(id: side) { geometry = nil; geometry = await BodyMapGeometry.figure(side) }   // never draw one side with the other's shapes
        .task(id: token) { await playReveal() }
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .accessibilityElement()
        .accessibilityLabel("\(side.rawValue.capitalized) body map")
    }

    /// Restarts the reveal and lets the fill timeline sleep once it has finished.
    private func playReveal() async {
        runner.restart()
        guard !still else { revealDone = true; return }
        revealDone = false
        let worked = levels.values.filter { $0 > 0 }.count
        let rv = config.reveal
        let total = rv.delayMs + Double(worked) * rv.staggerMs + rv.fillMs + 100
        try? await Task.sleep(for: .milliseconds(total))
        if !Task.isCancelled { revealDone = true }
    }

    // MARK: Layers

    private func baseLayer(k: CGFloat) -> some View {
        TimelineView(.animation(paused: revealDone)) { timeline in
            Canvas { ctx, size in
                guard let g = geometry else { return }
                let rv = config.reveal
                let now = revealDone ? 1e9 : runner.ms(timeline.date)
                let accent = (member ? accentHex.flatMap { BodyMapColor.rgb(hex: $0) } : nil) ?? BodyMapColor.rgb(hex: config.heatAccent) ?? (0.1, 0.65, 1)
                let base = BodyMapColor.rgb(hex: colors.muscle) ?? (0.8, 0.8, 0.8)
                var layer = ctx
                layer.scaleBy(x: k, y: k)
                layer.fill(g.outline, with: .color(Self.color(BodyMapColor.rgb(hex: colors.outline) ?? (0.9, 0.9, 0.9))))
                let ranks = BodyStardustEngine.ranks(levels: levels, shapes: g.muscles)
                for (i, m) in g.muscles.enumerated() {
                    var rgb = base
                    if let rank = ranks[i], let v = levels[m.id] {
                        let pr = BodyStardustEngine.ease((now - runner.t0 - rv.delayMs - Double(rank) * rv.staggerMs) / rv.fillMs)
                        rgb = BodyMapColor.mix(accent: accent, base: base, pct: (25 + v * 75) * pr)
                    }
                    layer.fill(m.path, with: .color(Self.color(rgb)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func starLayer(k: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / Double(max(1, config.fps)), paused: starsPaused)) { timeline in
            Canvas { ctx, size in
                guard let g = geometry else { return }
                // The engine holds indices into this side's muscles, so it is rebuilt whenever the side (geometry) changes too.
                let key = "\(side.rawValue)|\(g.muscles.count)|" + token
                if runner.engine == nil || runner.engineKey != key {
                    runner.engine = BodyStardustEngine(shapes: g.muscles, levels: levels, config: config, seed: UInt64.random(in: 1...UInt64.max),
                                                       now: runner.ms(timeline.date))
                    runner.engineKey = key
                }
                // One still frame (Low Power Mode, Reduce Motion) well into the reveal.
                let now = (lowPower || still) ? runner.t0 + 6000 : runner.ms(timeline.date)
                runner.engine?.step(now: now, t0: runner.t0)
                guard let muscles = runner.engine?.muscles else { return }
                guard muscles.allSatisfy({ $0.shapeIndex < g.muscles.count }) else { return }   // geometry changed mid-frame: skip it
                for m in muscles where !m.drawn.isEmpty {
                    var layer = ctx
                    var clipLayer = layer
                    clipLayer.scaleBy(x: k, y: k)
                    clipLayer.clip(to: g.muscles[m.shapeIndex].path)
                    layer = clipLayer
                    layer.transform = .identity
                    for s in m.drawn {
                        let x = s.x * k + s.swayX, y = s.y * k
                        let dot = Path(ellipseIn: CGRect(x: x - s.radius, y: y - s.radius, width: s.radius * 2, height: s.radius * 2))
                        layer.blendMode = s.gold ? .normal : .plusLighter
                        layer.fill(dot, with: .color(Color(.sRGB, red: s.r / 255, green: s.g / 255, blue: s.b / 255, opacity: s.alpha)))
                        if s.flareLength > 0 {
                            layer.blendMode = .plusLighter
                            var cross = Path()
                            cross.move(to: CGPoint(x: x - s.flareLength, y: y)); cross.addLine(to: CGPoint(x: x + s.flareLength, y: y))
                            cross.move(to: CGPoint(x: x, y: y - s.flareLength)); cross.addLine(to: CGPoint(x: x, y: y + s.flareLength))
                            let (fr, fg, fb) = s.gold ? (255.0, 214.0, 100.0) : (s.r, s.g, s.b)
                            layer.stroke(cross, with: .color(Color(.sRGB, red: fr / 255, green: fg / 255, blue: fb / 255, opacity: s.flareAlpha)), lineWidth: 0.6)
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func inkLayer(k: CGFloat) -> some View {
        Canvas { ctx, size in
            guard let g = geometry else { return }
            var layer = ctx
            layer.scaleBy(x: k, y: k)
            let ink = Self.color(BodyMapColor.rgb(hex: colors.ink) ?? (0.5, 0.5, 0.5))
            for p in g.ink { layer.fill(p, with: .color(ink)) }
        }
        .allowsHitTesting(false)
    }
}

/// Front and back figures side by side, labelled FRONT / BACK (the Body tab).
struct BodyMapView: View {
    var levels: [String: Double]
    var member = false
    var accentHex: String? = nil
    var replay = 0
    var showsLabels = true
    var spacing: CGFloat = 6
    var onTap: ((String) -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(BodyMapSide.allCases, id: \.self) { side in
                VStack(spacing: 6) {
                    if showsLabels {
                        Text(side.rawValue.uppercased()).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    }
                    BodyFigureView(side: side, levels: levels, member: member, accentHex: accentHex, replay: replay, onTap: onTap)
                        .accessibilityIdentifier(side == .front ? AX.body.figureFront : AX.body.figureBack)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Front and back figures at a fixed height, no labels (summary, share card, feed, friend profile).
struct BodyMapPair: View {
    var levels: [String: Double]
    var member = false
    var accentHex: String? = nil
    let height: CGFloat

    var body: some View {
        HStack(spacing: 2) {
            ForEach(BodyMapSide.allCases, id: \.self) { side in
                BodyFigureView(side: side, levels: levels, member: member, accentHex: accentHex).frame(height: height)
            }
        }
    }
}
