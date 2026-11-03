import SwiftUI
import SwiftData

/// Text field bound to a kg string but edited in the user's unit. Keeps its own text buffer so partial
/// input ("22.") isn't reformatted mid-typing; kg mode is a plain pass-through.
struct KgTextField: View {
    @Binding var kgString: String
    let unit: UnitPreference
    var placeholder: String = ""
    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .onAppear { text = unit.displayText(kgString: kgString) }
            .onChange(of: text) { _, new in
                let kg = unit.kgString(displayText: new)
                if kg != kgString { kgString = kg }
            }
            .onChange(of: kgString) { _, new in
                if unit.kgString(displayText: text) != new { text = unit.displayText(kgString: new) }
            }
            .onChange(of: unit) { _, _ in text = unit.displayText(kgString: kgString) }
    }
}

// MARK: - Set type chip

/// What sits in a set row's TYPE column: a dashed "+" while the set is standard, a coloured tag
/// (WU, DROP, AMRAP…) once a type is picked. Both fill the same box, so choosing a type never shifts
/// the row: the tag is never narrower than the placeholder and never wider than the column.
struct SetTypeChipLabel: View {
    let type: SetType

    static let height: CGFloat = 22
    /// The placeholder's width, and the narrowest a tag gets.
    static let minWidth: CGFloat = 28
    /// The TYPE column the row gives it, and the widest a tag gets.
    static let column: CGFloat = 36

    var body: some View {
        if type == .standard {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3]))
                    .foregroundStyle(Color.inkFaint)
                Text("+")
                    .font(.mono(9))
                    .foregroundStyle(Color.inkFaint)
            }
            .frame(width: Self.minWidth, height: Self.height)
        } else {
            let style = setTypeStyles[type] ?? setTypeStyles[.standard]!
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(style.bg)
                Text(style.label)
                    .font(.spaceMono(8, weight: .bold))
                    .foregroundStyle(style.fg)
                    .tracking(0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 2)
            }
            .frame(minWidth: Self.minWidth, maxWidth: Self.column, minHeight: Self.height, maxHeight: Self.height)
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}
