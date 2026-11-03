#if DEBUG
import SwiftUI

/// DEBUG: live sliders for the body map's Stardust, the design's four sample workouts, and Copy JSON. Long-press the figures.
struct BodyMapDevPanel: View {
    @Binding var presetIndex: Int?
    @Binding var memberOverride: Bool?
    var replay: () -> Void
    @State private var config = BodyMapConfigStore.shared.current

    static let presets: [(String, [String: Double])] = [
        ("PUSH", ["chest": 0.95, "upper_chest": 0.85, "front_delt": 0.8, "side_delt": 0.5, "tricep": 0.75, "traps": 0.2, "abs": 0.15, "rear_delt": 0.2, "upper_trap": 0.2]),
        ("PULL", ["lats": 0.95, "upper_trap": 0.6, "lower_trap": 0.7, "infraspinatus_teres_major": 0.8, "rear_delt": 0.75, "bicep_long_head": 0.85, "bicep_short_head": 0.8,
                  "brachioradialis": 0.6, "forearm_flexor": 0.5, "forearm_extensor": 0.5, "spinal_erector": 0.35, "traps": 0.5]),
        ("FULL BODY", ["chest": 0.85, "upper_chest": 0.7, "front_delt": 0.65, "side_delt": 0.55, "rear_delt": 0.5, "tricep": 0.55, "bicep_long_head": 0.6, "bicep_short_head": 0.55,
                       "brachioradialis": 0.4, "forearm_flexor": 0.35, "forearm_extensor": 0.35, "lats": 0.8, "upper_trap": 0.5, "lower_trap": 0.5, "traps": 0.5,
                       "infraspinatus_teres_major": 0.55, "spinal_erector": 0.6, "abs": 0.5, "obliques": 0.4, "external_oblique": 0.4, "glute_max": 0.85, "glute_med": 0.5,
                       "quad_rectus_femoris": 0.9, "quad_vastus_lateralis": 0.85, "quad_vastus_medialis": 0.8, "hamstring": 0.7, "adductor": 0.45, "calves": 0.4]),
        ("LEGS", ["quad_rectus_femoris": 0.95, "quad_vastus_lateralis": 0.9, "quad_vastus_medialis": 0.85, "adductor": 0.6, "calves": 0.5, "glute_max": 0.9, "glute_med": 0.6,
                  "hamstring": 0.8, "spinal_erector": 0.3, "abs": 0.2, "obliques": 0.2]),
    ]

    private func slider(_ name: String, _ v: Binding<Double>, _ r: ClosedRange<Double>) -> some View {
        HStack {
            Text(name).font(.spaceMono(10)).frame(width: 80, alignment: .leading)
            Slider(value: v, in: r)
            Text(String(format: "%.2f", v.wrappedValue)).font(.spaceMono(10)).frame(width: 40)
        }
    }

    private func apply() {
        BodyMapConfigStore.shared.override = config
        replay()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BODY MAP · DEBUG").font(.spaceMono(10, weight: .bold)).tracking(1.5)
            HStack {
                ForEach(Array(Self.presets.enumerated()), id: \.offset) { i, p in
                    Button(p.0) { presetIndex = i; replay() }.buttonStyle(.bordered)
                }
                Button("LIVE") { presetIndex = nil; replay() }.buttonStyle(.bordered)
            }
            HStack {
                Button("FREE") { memberOverride = false; replay() }.buttonStyle(.bordered)
                Button("MEMBER") { memberOverride = true; replay() }.buttonStyle(.bordered)
                Button("REPLAY") { replay() }.buttonStyle(.borderedProminent)
            }
            slider("amount", $config.amount, 0.2...3)
            slider("size", $config.size, 0.3...2)
            slider("flicker", $config.flicker, 0...1)
            slider("gold", $config.gold, 0...1)
            slider("flare", $config.flare, 0...2)
            slider("lifespan", $config.lifespan, 0.1...8)
            slider("sway", $config.sway, 0...3)
            Button("COPY JSON") {
                let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let d = try? enc.encode(config), let s = String(data: d, encoding: .utf8) { UIPasteboard.general.string = s }
            }.buttonStyle(.bordered)
        }
        .padding(16)
        .onChange(of: config) { _, _ in apply() }
    }
}
#endif
