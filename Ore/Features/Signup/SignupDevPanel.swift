#if DEBUG
import SwiftUI

/// DEBUG only, hidden: long-press the "ORE" mark on the sign-up screen. The live sky with a level scrubber and a SURGE
/// button, and sliders for the star count, speed, surge, easing, flashes, typing speed and the bullet dance, so the
/// screen can be tuned on a real device. Changes go through `SignupConfigStore.override` (the hook Remote Config uses);
/// the console picks them up the next time it is created. "Copy JSON" puts the values on the pasteboard in the shape of
/// `signup.config.json`.
struct SignupDevPanel: View {
    @State private var config = SignupConfigStore.shared.current
    @State private var level = 0.6
    @State private var generation = 0
    @State private var surge = SignupSurge()
    @State private var runner: SignupSkyRunner

    init() {
        let s = SignupSurge()
        _surge = State(initialValue: s)
        _runner = State(initialValue: SignupSkyRunner(config: SignupConfigStore.shared.current, surge: s))
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                SignupSkyColors.base
                SignupBackdrop(runner: runner, target: level).id(generation)
                VStack(alignment: .leading, spacing: 12) {
                    SignupProgressBar(config: config, surge: surge, progress: level)
                    HStack(spacing: 20) {
                        ForEach(0..<3, id: \.self) { i in
                            StarBullet(size: config.bullet.logSize, delay: -Double(i) * config.bullet.logOffset, config: config.bullet)
                        }
                    }
                }
                .padding(24)
            }
            .frame(maxHeight: .infinity)
            .clipped()

            ScrollView {
                VStack(spacing: 8) {
                    slider("level", $level, 0...1, step: 0.05)
                    Button("SURGE") { surge.boost = config.stars.boostAnswer }.font(.spaceMono(11, weight: .bold))
                    slider("stars (390×844)", $config.stars.count, 50...1500, step: 50)
                    slider("riseScale", $config.stars.riseScale, 0.1...2, step: 0.05)
                    slider("boostRise", $config.stars.boostRise, 0...2, step: 0.05)
                    slider("boostDecay", $config.stars.boostDecay, 0.8...0.99, step: 0.01)
                    slider("levelEase", $config.stars.levelEase, 0.01...0.3, step: 0.01)
                    slider("flashProb", $config.stars.flashProb, 0...0.02, step: 0.001)
                    slider("gold share", $config.stars.gold, 0...0.8, step: 0.05)
                    slider("fps", Binding(get: { Double(config.stars.fps) }, set: { config.stars.fps = Int($0) }), 10...60, step: 5)
                    slider("typing ms/char", Binding(get: { Double(config.typing.msPerChar) }, set: { config.typing.msPerChar = Int($0) }), 0...100, step: 2)
                    slider("bullet seconds", $config.bullet.seconds, 0.8...6, step: 0.2)
                    slider("bullet scale max", $config.bullet.scaleMax, 1...1.6, step: 0.02)
                    HStack {
                        Button("Reset") { config = SignupConfigStore.shared.base; SignupConfigStore.shared.override = nil; rebuild() }
                        Spacer()
                        Button("Copy JSON") {
                            let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                            UIPasteboard.general.string = (try? enc.encode(config)).flatMap { String(data: $0, encoding: .utf8) }
                        }
                    }
                    .font(.spaceMono(11, weight: .bold))
                }
                .padding(16)
            }
            .frame(maxHeight: 340)
            .background(Color.canvasBg)
        }
        .onChange(of: config) { _, new in
            SignupConfigStore.shared.override = new
            rebuild()
        }
    }

    private func rebuild() {
        runner = SignupSkyRunner(config: config, surge: surge)
        generation += 1
    }

    private func slider(_ name: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, step: Double) -> some View {
        HStack {
            Text(name).font(.spaceMono(10)).frame(width: 110, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(String(format: "%g", value.wrappedValue)).font(.spaceMono(10, weight: .bold)).frame(width: 52, alignment: .trailing)
        }
        .foregroundStyle(Color.inkPrimary)
    }
}
#endif
