import SwiftUI

/// Seven day bars with their letters (the design system's `WeekBars`): a bar's height is its share of the busiest day, a day with
/// nothing is a stub, a trained day uses the "up" signal, today uses the accent.
struct WeekBars: View {
    let data: [Double]
    var done: [Bool] = []
    var labels = ["M", "T", "W", "T", "F", "S", "S"]
    /// Index of today, -1 for none.
    var today = -1
    var height: CGFloat = 40

    var body: some View {
        let peak = max(data.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(data.enumerated()), id: \.offset) { i, v in
                let isToday = i == today
                let isDone = i < done.count && done[i]
                let barHeight = max(v > 0 ? CGFloat(v / peak) * height : 3, 3)
                let colour: Color = isToday ? .oreAccent : isDone ? .signalUp : v > 0 ? .inkPrimary : .inkFaint
                let opacity: Double = isToday ? 1 : isDone ? 0.7 : v > 0 ? 0.35 : 0.4
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2).fill(colour).opacity(opacity).frame(height: barHeight)
                    Text(i < labels.count ? labels[i] : "")
                        .font(.spaceMono(7, weight: isToday ? .bold : .regular))
                        .tracking(0.5)
                        .foregroundStyle(isToday ? Color.accentInk : Color.inkMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height + 18, alignment: .bottom)
    }
}
