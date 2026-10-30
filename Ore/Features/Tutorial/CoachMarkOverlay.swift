import SwiftUI

/// Eases the spotlight and card toward where they should be, so steps glide instead of jumping.
/// A plain reference type: it is advanced from inside the per-frame timeline, not observed.
private final class OverlayMotion {
    var hole: CGRect?
    var cardY: CGFloat?
    private var lastTick: TimeInterval = 0
    private var lostSince: TimeInterval?
    private var step: TutorialStep?
    private(set) var stepChangedAt: TimeInterval = 0
    private var transitioning = false
    private(set) var transitionChangedAt: TimeInterval = 0
    /// The spotlight as it was when the hand-over started: the closing animation shrinks this.
    private var frozenHole: CGRect?

    /// How fast things follow: higher is snappier. Scrolling stays tight, step changes still glide.
    private let rate = 7.0

    /// True while anything on the overlay is moving or fading. The overlay's clock runs at full speed then and
    /// ticks slowly otherwise (still often enough to notice a target that moved), so a resting tutorial costs
    /// almost nothing.
    private(set) var isActive = true
    private var lastTarget: CGRect?
    private var activeUntil: TimeInterval = 0

    /// Whether the finger is showing. It appears once the spotlight has arrived (within 4pt) and then stays
    /// until the target moves a long way (16pt): a target that jitters a few points, as the Home dock can,
    /// must not make the finger vanish and restart its loop.
    private(set) var fingerShown = false

    func updateFinger(target: CGRect?) {
        guard let t = target, let h = hole else { fingerShown = false; return }
        let d = max(abs(h.midX - t.midX), abs(h.midY - t.midY))
        fingerShown = fingerShown ? d < 16 : d < 4
    }

    /// Called once per tick with what was just worked out.
    func noteFrame(now: TimeInterval, target: CGRect?, cardOpacity: CGFloat, transitioning: Bool) {
        if target != lastTarget { lastTarget = target; activeUntil = now + 0.6 }
        let holeMoving: Bool = {
            guard let h = hole, let t = target else { return hole != nil || target != nil }
            return abs(h.minX - t.minX) > 0.25 || abs(h.minY - t.minY) > 0.25 || abs(h.width - t.width) > 0.25 || abs(h.height - t.height) > 0.25
        }()
        let fading = cardOpacity > 0.001 && cardOpacity < 0.999 || (transitioning && cardOpacity > 0.001)
        isActive = holeMoving || fading || transitioning || now < activeUntil || now - stepChangedAt < 1.0
    }
    /// How long the spotlight and card take to clear when the user acts. Short, and measured on the clock
    /// rather than counted in frames, so it is done by the time the next screen starts moving.
    private let closeSeconds = 0.10
    private let cardFadeSeconds = 0.12

    func tick(now: TimeInterval, step current: TutorialStep, transitioning now_: Bool) -> CGFloat {
        let dt = min(max(now - lastTick, 0), 0.05)
        lastTick = now
        if step != current {
            step = current
            stepChangedAt = now
            // A new step opens its own spotlight at its target, instead of sliding over from the last
            // one across whatever screen has moved in since.
            hole = nil
            cardY = nil
            frozenHole = nil
        }
        if transitioning != now_ {
            transitioning = now_
            transitionChangedAt = now
            frozenHole = now_ ? hole : nil
        }
        return CGFloat(1 - exp(-dt * rate))
    }

    /// 1 when the card is fully shown. It fades out the instant the user acts (so no old text rides
    /// along while the next screen moves in) and fades the next step's card in once it is current.
    func cardOpacity(now: TimeInterval) -> CGFloat {
        if transitioning { return CGFloat(max(0, 1 - (now - transitionChangedAt) / cardFadeSeconds)) }
        let since = now - max(stepChangedAt, transitionChangedAt)
        return CGFloat(min(max((since - 0.2) / 0.55, 0), 1))
    }

    /// While a step is handing over, the spotlight closes on the clock instead of lingering on the old
    /// target; the next one opens from its own centre.
    func moveHole(toward target: CGRect?, now: TimeInterval, by a: CGFloat, closing: Bool = false) {
        if closing {
            guard let f = frozenHole else { hole = nil; return }
            let p = min(max((now - transitionChangedAt) / closeSeconds, 0), 1)
            hole = p >= 1 ? nil : Self.lerp(f, CGRect(x: f.midX, y: f.midY, width: 0, height: 0), CGFloat(p))
            lostSince = nil
            return
        }
        if let target {
            lostSince = nil
            if let h = hole {
                let next = Self.lerp(h, target, a)
                // Close enough counts as arrived: lets the spotlight settle exactly, so nothing redraws while it rests.
                hole = Self.near(next, target) ? target : next
            } else {
                // First appearance: open from the target's centre.
                let seed = CGRect(x: target.midX, y: target.midY, width: 0, height: 0)
                hole = Self.lerp(seed, target, max(a, 0.2))
            }
        } else if let h = hole {
            // A target that is briefly missing (a screen sliding in) keeps its spotlight; a lasting
            // absence closes it.
            let since = lostSince ?? now
            lostSince = since
            guard now - since > 0.4 else { return }
            let closed = Self.lerp(h, CGRect(x: h.midX, y: h.midY, width: 0, height: 0), a)
            hole = closed.width < 1 ? nil : closed
        }
    }

    private static func near(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 0.25 && abs(a.minY - b.minY) < 0.25 && abs(a.width - b.width) < 0.25 && abs(a.height - b.height) < 0.25
    }

    /// `snap`: the card is invisible, so it jumps to its place instead of sliding with new text on it.
    func moveCard(toward y: CGFloat, by a: CGFloat, snap: Bool) {
        cardY = (snap ? nil : cardY).map { $0 + (y - $0) * a } ?? y
    }

    static func lerp(_ f: CGRect, _ t: CGRect, _ a: CGFloat) -> CGRect {
        CGRect(x: f.minX + (t.minX - f.minX) * a, y: f.minY + (t.minY - f.minY) * a,
               width: f.width + (t.width - f.width) * a, height: f.height + (t.height - f.height) * a)
    }
}

/// The overlay's clock: every frame while something is moving, a few times a second while it rests.
private struct AdaptiveSchedule: TimelineSchedule {
    let motion: OverlayMotion

    func entries(from start: Date, mode: TimelineScheduleMode) -> Entries {
        Entries(upcoming: start, motion: motion)
    }

    struct Entries: Sequence, IteratorProtocol {
        var upcoming: Date
        let motion: OverlayMotion

        mutating func next() -> Date? {
            let now = upcoming
            upcoming = now.addingTimeInterval(motion.isActive ? 1.0 / 60 : 0.12)
            return now
        }
    }
}

/// The dim with a soft-edged hole in it, and a faint glow around the target. `Equatable`, so SwiftUI skips
/// redrawing it while the spotlight rests.
///
/// The soft edge is a stack of rounded rectangles, each erasing a little more of the dim than the one outside
/// it, rather than a blur filter: filters are redrawn on the CPU on every frame of the spotlight's glide, and
/// that made the tutorial slow.
struct SpotlightLayer: View, Equatable {
    var hole: CGRect?
    var keyboard: CGRect
    var dim: Color
    var glow: Color

    /// How many steps the falloff has, and how far out the faintest one reaches.
    private static let steps = 32
    private static let reach: CGFloat = 22

    /// The light follows the controls' own rounded-rectangle shape (every button here is a rounded rectangle,
    /// the + at the top included). `grow` is how far this layer sits outside it.
    static func cornerRadius(for rect: CGRect, grow: CGFloat) -> CGFloat {
        min(10, min(rect.width, rect.height) / 2) + grow * 0.8
    }

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(dim))
            var erase = ctx
            erase.blendMode = .destinationOut
            let n = Self.steps
            if let h = hole {
                // Outermost first. Each layer clears a little more, and the opacities are chosen so the total
                // cleared after k layers follows a smoothstep: dim at the far edge, clear at the control, no seam.
                let reach = min(Self.reach, max(10, min(h.width, h.height) * 0.42))
                var previous: CGFloat = 0
                for k in 1...n {
                    let u = CGFloat(k) / CGFloat(n)
                    let total = u * u * u * (u * (u * 6 - 15) + 10)                     // cleared so far, 0…1
                    let alpha = k == n ? 1 : (total - previous) / (1 - previous)
                    previous = total
                    let grow = reach * CGFloat(n - k) / CGFloat(n - 1)    // reach for the first layer, 0 for the last
                    erase.fill(Path(roundedRect: h.insetBy(dx: -grow, dy: -grow), cornerRadius: Self.cornerRadius(for: h, grow: grow)),
                               with: .color(.black.opacity(Double(alpha))))
                }
            }
            if keyboard != .zero {
                for i in 0..<4 {
                    let grow = CGFloat(3 - i) * 5
                    erase.fill(Path(keyboard.insetBy(dx: -grow, dy: -grow).offsetBy(dx: 0, dy: grow)), with: .color(.black.opacity(0.5)))
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {}   // swallow taps outside the spotlight
    }
}

/// The tutorial layer: the app stays visible under a light dim, the target is clear, an animated
/// finger shows the gesture, and a short card explains it. It lives in `TutorialOverlayWindow`, so it
/// sits above sheets and covers.
struct CoachMarkOverlay: View {
    @Bindable var viewModel: TutorialViewModel
    @AppStorage("appTheme") private var appTheme: String = AppTheme.system.rawValue

    private var targets: TutorialTargets { .shared }
    @State private var cardHeight: CGFloat = 190
    @State private var motion = OverlayMotion()

    private var safeTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
            .first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 47
    }

    var body: some View {
        // Every frame while something moves, so the spotlight tracks scrolling and glides between steps;
        // a few times a second otherwise.
        TimelineView(AdaptiveSchedule(motion: motion)) { ctx in
            GeometryReader { proxy in
                layers(now: ctx.date.timeIntervalSinceReferenceDate, size: proxy.size)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(AppTheme(rawValue: appTheme)?.colorScheme)
        .task(id: "\(viewModel.currentStep.rawValue)-\(targets.keyboardFrame != .zero)") { await revealTargetIfHidden() }
    }

    @ViewBuilder
    private func layers(now: TimeInterval, size: CGSize) -> some View {
        if viewModel.isFinished {
            completion
        } else {
            let step = viewModel.currentStep
            let a = motion.tick(now: now, step: step, transitioning: viewModel.isTransitioning)
            let raw = targets.frame(step.target).map(TutorialPresenter.hole(for:))
                .flatMap { $0.intersects(CGRect(origin: .zero, size: size)) ? $0 : nil }
            let _ = motion.moveHole(toward: raw, now: now, by: a, closing: viewModel.isTransitioning)
            let hole = motion.hole
            // The finger waits until the spotlight has arrived, so it never points at a moving target.
            let _ = motion.updateFinger(target: raw)
            let settled = motion.fingerShown
            let cardOpacity = motion.cardOpacity(now: now)
            let _ = motion.noteFrame(now: now, target: raw, cardOpacity: cardOpacity, transitioning: viewModel.isTransitioning)

            ZStack(alignment: .top) {
                dim(hole: hole, size: size)
                if let raw, settled, step.gesture != .auto, !viewModel.isTransitioning {
                    TouchHint(
                        point: touchPoint(for: step, in: raw),
                        gesture: step.gesture,
                        // The pull slides down most of the zone and stops above the card, so all of it shows.
                        slide: step.gesture == .swipeDown ? raw.height * 0.78 : 130
                    )
                    .id(step)
                    .transition(.opacity)
                }
                card(hole: hole, size: size, a: a, snap: cardOpacity < 0.02)
                    .opacity(cardOpacity)
                    // The card fades by its own clock. Without this, SwiftUI cross-dissolves the title and
                    // text when the step changes, so the old words linger under the new ones.
                    .transaction { $0.animation = nil }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    /// The finger's landing point: the centre of the control it should touch if the step names one,
    /// else a spot inside the spotlight picked to stay off its text.
    private func touchPoint(for step: TutorialStep, in spot: CGRect) -> CGPoint {
        if let id = step.touchTarget, let f = targets.frame(id) { return CGPoint(x: f.midX, y: f.midY) }
        return CGPoint(x: spot.minX + spot.width * step.touchAnchor.x, y: spot.minY + spot.height * step.touchAnchor.y)
    }

    /// A target below the fold (ADD EXERCISE under a long workout) is scrolled into view by its screen.
    private func revealTargetIfHidden() async {
        for _ in 0..<6 {
            try? await Task.sleep(for: .milliseconds(700))
            guard !viewModel.isFinished else { return }
            let screen = UIScreen.main.bounds
            // Room for the card too: the target has to sit clear of the keyboard when it is up.
            let kb = targets.keyboardFrame
            let bottom = kb == .zero ? screen.maxY - 110 : kb.minY - 16
            let visible = CGRect(x: 0, y: safeTop + 60, width: screen.width, height: bottom - safeTop - 60)
            if let f = targets.frame(viewModel.currentStep.target), visible.contains(CGPoint(x: f.midX, y: f.midY)) { return }
            NotificationCenter.default.post(name: .tutorialRevealTarget, object: viewModel.currentStep.target)
            try? await Task.sleep(for: .milliseconds(1100))   // let the slow scroll finish before judging again
        }
    }

    // MARK: Dim + spotlight

    /// Light enough that the rest of the page stays readable.
    private var dimColor: Color { Color.black.opacity(0.38) }

    /// A spotlight, not a cut-out: the light is full strength over the target and falls off into the
    /// dim over a few dozen points, so there is no hard edge anywhere. Drawn in one pass, and only
    /// redrawn when the spotlight actually moves.
    private func dim(hole: CGRect?, size: CGSize) -> some View {
        SpotlightLayer(hole: hole.map(TutorialPresenter.lit), keyboard: targets.keyboardFrame,
                       dim: dimColor, glow: Color.accentInk.opacity(0.5))
            .equatable()
    }

    // MARK: Tooltip card

    /// The card sits right beside the spotlight, so the eye has one place to look. `cardSide` and the
    /// spotlight's position pick above or below; the other side is the fallback when there is no room.
    private func cardTarget(hole: CGRect?, size: CGSize) -> CGFloat {
        let minTop = safeTop + 12
        let kb = targets.keyboardFrame
        let bottom = (kb == .zero ? size.height - 28 : kb.minY) - 12
        guard let hole else { return bottom - cardHeight }
        let gap: CGFloat = 20   // clear of the soft light around the target
        let roomBelow = bottom - hole.maxY - gap
        let roomAbove = hole.minY - minTop - gap
        let preferAbove: Bool
        switch viewModel.currentStep.cardSide {
        case .above: preferAbove = true
        case .below: preferAbove = false
        case .auto: preferAbove = roomAbove > roomBelow   // wherever there is more room
        }
        let below = hole.maxY + gap, above = hole.minY - gap - cardHeight
        if preferAbove {
            if roomAbove >= cardHeight { return above }
            if roomBelow >= cardHeight { return below }
        } else {
            if roomBelow >= cardHeight { return below }
            if roomAbove >= cardHeight { return above }
        }
        // No room either side: stay as close as the screen allows.
        return roomBelow >= roomAbove ? min(below, bottom - cardHeight) : max(above, minTop)
    }

    private func card(hole: CGRect?, size: CGSize, a: CGFloat, snap: Bool) -> some View {
        let step = viewModel.currentStep
        motion.moveCard(toward: cardTarget(hole: hole, size: size), by: a, snap: snap)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(step.phase.uppercased())
                    .font(.spaceMono(9, weight: .bold)).tracking(0.8)
                    .foregroundStyle(Color.accentInk)
                    .padding(.horizontal, 8).frame(height: 19)
                    .background(Color.accentSoft)
                    .clipShape(Capsule())
                Spacer()
                Text(String(format: "%02d / %d", step.rawValue + 1, TutorialStep.allCases.count))
                    .font(.spaceMono(9)).tracking(0.5).foregroundStyle(Color.inkMuted)
                Button("SKIP") { viewModel.skip() }
                    .font(.spaceMono(9)).tracking(0.8).foregroundStyle(Color.inkMuted)
                    .padding(.leading, 10).padding(.vertical, 6).contentShape(Rectangle())
                    .accessibilityIdentifier(AX.tutorial.skip)
            }
            .padding(.bottom, 4)

            Text(step.title)
                .font(.archivo(19, weight: .black))
                .foregroundStyle(Color.inkPrimary)
                .padding(.bottom, 4)
                .accessibilityIdentifier(AX.tutorial.card)
            Text(step.description)
                .font(.archivo(13))
                .foregroundStyle(Color.inkPrimary.opacity(0.7))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)

            HStack(spacing: 6) {
                Circle().fill(Color.accentInk).frame(width: 6, height: 6)
                Text(step.gesture.label)
                    .font(.spaceMono(10, weight: .bold)).tracking(1.2)
                    .foregroundStyle(Color.accentInk)
            }
        }
        .padding(.top, 10).padding(.horizontal, 14).padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.canvasBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.ruleStrong, lineWidth: 1))
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeight = $0 }
        .padding(.horizontal, 14)
        .offset(y: motion.cardY ?? 0)
    }

    // MARK: Completion

    private var completion: some View {
        ZStack {
            Color(hex: "#1a1816").ignoresSafeArea()
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.oreAccent)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.bottom, 28)
                Text("ORE")
                    .font(.spaceMono(11)).tracking(2.5)
                    .foregroundStyle(Color(hex: "#ece5d6").opacity(0.5))
                    .padding(.bottom, 12)
                Text("YOU'RE\nALL SET.")
                    .font(.archivo(44, weight: .black)).tracking(-1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: "#ece5d6"))
                    .padding(.bottom, 20)
                Text("Go build something worth logging.")
                    .font(.archivo(15))
                    .foregroundStyle(Color(hex: "#ece5d6").opacity(0.5))
                    .padding(.bottom, 44)
                Button { viewModel.complete() } label: {
                    Text("START TRAINING →")
                        .font(.archivo(18, weight: .black)).tracking(2)
                        .foregroundStyle(Color.onAccent)
                        .frame(maxWidth: .infinity).frame(height: 58)
                        .background(Color.oreAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AX.tutorial.next)
                .padding(.bottom, 14)
                Button { viewModel.start() } label: {
                    Text("REPLAY TUTORIAL")
                        .font(.spaceMono(10)).tracking(1)
                        .foregroundStyle(Color(hex: "#ece5d6").opacity(0.5))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Touch hint

/// A finger showing the gesture: a ring closes in on the touch point, the finger presses, and a tap
/// ripples out. A swipe presses, then slides (left, or down for the pull) leaving a faint trail. One
/// `Canvas`, so the loop costs a handful of path fills a frame.
private struct TouchHint: View {
    let point: CGPoint
    let gesture: TutorialGesture
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Each appearance starts from the ring's first frame, not from wherever the clock happens to be.
    @State private var start = Date()

    private let dot: CGFloat = 22
    var slide: CGFloat = 130
    private var slidesDown: Bool { gesture == .swipeDown }

    /// The only area the finger ever draws in: the closing ring, plus the slide for a swipe. Redrawing a canvas
    /// this size every frame costs far less than redrawing the whole screen.
    private var box: CGRect {
        let margin: CGFloat = 80
        switch gesture {
        case .swipeLeft: return CGRect(x: point.x - margin - slide, y: point.y - margin, width: margin * 2 + slide, height: margin * 2)
        case .swipeDown: return CGRect(x: point.x - margin, y: point.y - margin, width: margin * 2, height: margin * 2 + slide)
        default: return CGRect(x: point.x - margin, y: point.y - margin, width: margin * 2, height: margin * 2)
        }
    }

    var body: some View {
        let area = box
        return Group {
            if reduceMotion {
                Canvas { ctx, _ in
                    var c = ctx
                    c.translateBy(x: -area.minX, y: -area.minY)
                    drawFinger(&c, at: point, scale: 1, opacity: 1)
                }
            } else {
                TimelineView(.animation) { timeline in
                    Canvas { ctx, _ in
                        var c = ctx
                        c.translateBy(x: -area.minX, y: -area.minY)
                        draw(&c, t: timeline.date.timeIntervalSince(start))
                    }
                }
            }
        }
        .frame(width: area.width, height: area.height)
        .position(x: area.midX, y: area.midY)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }
    private func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    private func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
    private func span(_ p: Double, _ a: Double, _ b: Double) -> Double { clamp((p - a) / (b - a)) }

    /// The accent ring over a white one, so it shows on the dim and on the lit control alike.
    private func ring(_ ctx: inout GraphicsContext, centre: CGPoint, radius: CGFloat, width: CGFloat, opacity: Double) {
        guard opacity > 0.01, radius > 1 else { return }
        var c = ctx
        c.opacity = opacity
        c.stroke(Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)),
                 with: .color(Color.accentInk), lineWidth: width)
        let inner = radius - 2.5
        if inner > 1 {
            c.stroke(Path(ellipseIn: CGRect(x: centre.x - inner, y: centre.y - inner, width: inner * 2, height: inner * 2)),
                     with: .color(.white), lineWidth: 1.5)
        }
    }

    private func drawFinger(_ ctx: inout GraphicsContext, at centre: CGPoint, scale: CGFloat, opacity: Double) {
        guard opacity > 0.01 else { return }
        let r = dot / 2 * scale
        var c = ctx
        c.opacity = opacity
        // See-through, so text under the finger stays readable.
        c.fill(Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2)), with: .color(Color.accentInk.opacity(0.28)))
        ring(&c, centre: centre, radius: r, width: 2, opacity: 1)
    }

    private func draw(_ ctx: inout GraphicsContext, t: TimeInterval) {
        let swipe = gesture == .swipeLeft || gesture == .swipeDown
        let cycle = swipe ? 3.2 : 2.0
        let p = t.truncatingRemainder(dividingBy: cycle)

        // 1. A ring closes in on the touch point.
        let approach = easeOut(span(p, 0, 0.8))
        let ringR = 32 - (32 - Double(dot) / 2) * approach
        let ringOpacity = clamp(p / 0.2) * 0.85 * (1 - span(p, 0.7, 0.85))

        // 2. The finger lands and presses.
        let press = span(p, 0.75, 0.95)
        let appear = span(p, 0.5, 0.75)

        // 3a. Tap: release and ripple.  3b. Swipe: slide.
        let releaseAt = swipe ? 2.2 : 0.95
        let ripple = swipe ? 0 : span(p, 0.95, 1.6)
        let travel = swipe ? ease(span(p, 0.95, 2.1)) * Double(slide) : 0
        let release = span(p, releaseAt, releaseAt + 0.2)
        let fade = swipe ? span(p, 2.3, 2.6) : span(p, 1.55, 1.8)
        let scale = 1 - 0.18 * press + 0.18 * release
        let dotOpacity = appear * (1 - fade)

        if swipe && travel > 1 {
            // The trail stays where the finger started and fades toward where it is now.
            let h = dot * 0.7
            var c = ctx
            c.opacity = 1 - fade
            let gradient = Gradient(colors: [Color.accentInk.opacity(0), Color.accentInk.opacity(0.55)])
            if slidesDown {
                let rect = CGRect(x: point.x - h / 2, y: point.y - dot / 2, width: h, height: travel + dot)
                c.fill(Path(roundedRect: rect, cornerRadius: h / 2),
                       with: .linearGradient(gradient, startPoint: CGPoint(x: rect.midX, y: rect.maxY), endPoint: CGPoint(x: rect.midX, y: rect.minY)))
            } else {
                let rect = CGRect(x: point.x - travel - dot / 2, y: point.y - h / 2, width: travel + dot, height: h)
                c.fill(Path(roundedRect: rect, cornerRadius: h / 2),
                       with: .linearGradient(gradient, startPoint: CGPoint(x: rect.minX, y: rect.midY), endPoint: CGPoint(x: rect.maxX, y: rect.midY)))
            }
        }
        ring(&ctx, centre: point, radius: CGFloat(ringR), width: 2, opacity: ringOpacity)
        if ripple > 0 {
            var c = ctx
            c.opacity = 0.7 * (1 - ripple)
            let r = (dot + 20 * ripple) / 2
            c.stroke(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                     with: .color(Color.accentInk), lineWidth: 2)
        }
        drawFinger(&ctx, at: CGPoint(x: slidesDown ? point.x : point.x - travel, y: slidesDown ? point.y + travel : point.y),
                   scale: scale, opacity: dotOpacity)
    }
}
