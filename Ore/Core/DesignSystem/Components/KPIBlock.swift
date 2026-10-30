import SwiftUI

/// Compact KPI cell — label + value (+ optional muted trailing delta/denominator).
/// Matches the design system's `KPIBlock` compact variant: label is Space Mono 400 7px /
/// 1.2px tracking / muted; value is Archivo 900 22px / line-height 0.9. Ignores a
/// denominator prop by design — where a stat needs a coloured value (e.g. "6 OF 9" with
/// the "6" in green), build that inline rather than through this component.
struct KPIBlock: View {
    let label: String
    let value: String
    var valueColor: Color = Color.inkPrimary
    /// Small muted trailing text after the value, e.g. "OF 2,412" on a RANK block.
    var delta: String?
    /// Colour of `delta` (muted unless set; the design colours a rising figure with the "up" signal).
    var deltaColor: Color = Color.inkMuted
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(label)
                .font(.spaceMono(7))
                // `.tracking()` pads *after* the last glyph too, which widens this Text's
                // layout box past its visible characters and throws off center alignment
                // against the untracked value below it (the box's centerline sits right of
                // what's actually visible). `.kerning()` renders identically but doesn't
                // add that trailing pad, so the label centers correctly under the value.
                .kerning(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.inkMuted)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.archivo(22, weight: .black))
                    .lineSpacing(0)
                    .foregroundStyle(valueColor)
                if let delta {
                    Text(delta)
                        .font(.spaceMono(8))
                        .foregroundStyle(deltaColor)
                }
            }
        }
        .frame(maxWidth: alignment == .center ? .infinity : nil, alignment: Alignment(horizontal: alignment, vertical: .center))
    }
}

#Preview {
    HStack(spacing: 16) {
        KPIBlock(label: "Sets", value: "30")
        KPIBlock(label: "Volume", value: "13.4K")
        KPIBlock(label: "Streak", value: "13D")
        KPIBlock(label: "PRs", value: "2", valueColor: .prGold)
    }
    .padding()
}
