#if DEBUG
import SwiftUI

/// DEBUG only, hidden: long-press the "MORE" title (or launch with `-debugSupernova stardust`). A live Stardust with sliders for
/// density, speed, gold, sparkle, goldPull and fps, so the Stardust can be tuned on a real device. Changes go through
/// `StardustConfigStore.override`, the same hook a remote config would use. "Copy JSON" puts the values on the pasteboard in the
/// shape of `stardust.config.json`.
struct StardustDevPanel: View {
    @State private var config: StardustConfig = StardustConfigStore.shared.current
    @State private var variant = "paywall"
    @State private var generation = 0
    @State private var anchor: CGRect?

    private let variants = ["paywall", "banner", "tag", "avatar", "rowIcon", "recapCard"]

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Color.black
                StardustView(variant: variant, budget: .paywall, anchor: anchor, config: config)
                    .id("\(variant)-\(generation)")
                SupernovaWordmark(size: 40, tracking: -0.5)
                    .padding(24)
                    .onPreferenceChange(SupernovaAsteriskFrameKey.self) { anchor = $0 }
            }
            .frame(maxHeight: .infinity)
            .clipped()

            VStack(spacing: 8) {
                Picker("Variant", selection: $variant) { ForEach(variants, id: \.self) { Text($0) } }
                    .pickerStyle(.segmented)
                slider("density", $config.density, 100...3000, step: 100)
                slider("speed", $config.speed, 0.3...3, step: 0.1)
                slider("gold", $config.gold, 0...0.4, step: 0.02)
                slider("sparkle", $config.sparkle, 0...1.5, step: 0.05)
                slider("goldPull", $config.goldPull, 0...400, step: 10)
                slider("fps (paywall)", Binding(get: { Double(config.fps.paywall) }, set: { config.fps.paywall = Int($0) }), 10...60, step: 5)
                slider("fps (more)", Binding(get: { Double(config.fps.more) }, set: { config.fps.more = Int($0) }), 10...60, step: 5)
                HStack {
                    Button("Reset") { config = StardustConfigStore.shared.base; StardustConfigStore.shared.override = nil; generation += 1 }
                    Spacer()
                    Button("Copy JSON") {
                        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
                        UIPasteboard.general.string = (try? enc.encode(config)).flatMap { String(data: $0, encoding: .utf8) }
                    }
                }
                .font(.spaceMono(11, weight: .bold))
            }
            .padding(16)
            .background(Color.canvasBg)
        }
        .onChange(of: config) { _, new in
            StardustConfigStore.shared.override = new   // new fields (the rest of the app) pick it up too
            generation += 1
        }
    }

    private func slider(_ name: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, step: Double) -> some View {
        HStack {
            Text(name).font(.spaceMono(10)).frame(width: 96, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(String(format: step < 1 ? "%.2f" : "%.0f", value.wrappedValue)).font(.spaceMono(10)).frame(width: 44, alignment: .trailing)
        }
        .foregroundStyle(Color.inkPrimary)
    }
}
#endif
