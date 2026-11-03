import SwiftUI

/// The dim behind every logger sheet and modal: rgba(21,26,33,0.35), never a blur.
enum LoggerDim {
    static let color = Color(red: 21 / 255, green: 26 / 255, blue: 33 / 255).opacity(0.35)
}

/// A row of the ··· popover: 44 pt, title left, a small value right (ON / OFF, 2:30 ›, GROUP A …).
struct LoggerMenuRow: View {
    let title: String
    var value: String? = nil
    var valueColor: Color = .inkMuted
    var bold = true
    var destructive = false
    var divider = true
    /// The tutorial spotlights this row while it is walking through the exercise.
    var tutorialID: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title).font(.archivo(14, weight: .semibold)).foregroundStyle(destructive ? Color.signalDown : Color.inkPrimary)
                Spacer(minLength: 6)
                if let value {
                    Text(value).font(.spaceMono(9, weight: bold ? .bold : .regular)).tracking(1.5).foregroundStyle(valueColor).lineLimit(1)
                }
            }
            .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { if divider { Rectangle().fill(Color.dsHairLine).frame(height: 1) } }
        }
        .buttonStyle(OreRowPressStyle())
        .accessibilityIdentifier(AX.workout.menuRow(title))
        .tutorialTarget(tutorialID ?? "", enabled: tutorialID != nil)
    }
}

/// The logger's bottom sheet shell: dim behind (tap closes), canvas sheet with a 36 × 4 handle and radius 14 on top.
struct LoggerSheet<Content: View>: View {
    var onClose: () -> Void
    var maxHeightFraction: CGFloat = 0.88
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .bottom) {
            LoggerDim.color.ignoresSafeArea().onTapGesture(perform: onClose).accessibilityIdentifier(AX.workout.sheetClose)
            VStack(spacing: 12) {
                Capsule().fill(Color.inkGhost).frame(width: 36, height: 4)
                content
            }
            .padding(.top, 8).padding(.bottom, 30)
            .frame(maxWidth: .infinity)
            .background(Color.canvasBg.ignoresSafeArea(edges: .bottom))
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 14, style: .continuous))
            .frame(maxHeight: UIScreen.main.bounds.height * maxHeightFraction)
            .transition(.move(edge: .bottom))
        }
    }
}

/// 8 pt label (Space Mono, muted) used all over the sheets.
struct LoggerLabel: View {
    let text: String
    var body: some View { Text(text).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted) }
}

/// A 56 pt full-width sheet button (SKIP REST / SAVE ✓): radius 12, label left, glyph right.
struct SheetButton: View {
    let title: String
    let glyph: String
    var filled = false
    var id: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.archivo(17, weight: .black)).tracking(0.6)
                Spacer()
                Text(glyph).font(.archivo(22, weight: .black))
            }
            .foregroundStyle(filled ? Color.white : Color.inkPrimary).padding(.horizontal, 20).frame(height: 56).frame(maxWidth: .infinity)
            .background { if filled { AccentFill() } else { Color.surf2 } }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressOpacityButtonStyle()).axID(id)
    }
}
