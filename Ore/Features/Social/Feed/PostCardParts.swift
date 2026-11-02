import SwiftUI

/// Small pieces of the feed post (Ore Feed Post Final §1): the drawn play / pause icons, the popover menu, the Title Case rule.

extension String {
    /// Exercise names are Title Case in data ("Back Squat"): each word capitalised, words already in capitals ("EZ") left alone.
    var exerciseTitleCase: String {
        split(separator: " ", omittingEmptySubsequences: true).map { w -> String in
            let s = String(w)
            if s == s.uppercased(), s.count <= 3, s.contains(where: \.isLetter) { return s }
            return s.prefix(1).uppercased() + s.dropFirst().lowercased()
        }.joined(separator: " ")
    }
}

/// A play triangle with rounded corners, drawn (no text glyph).
struct RoundedPlayTriangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// The 32 pt play / pause key of the song row: white drawn icon on the poster's accent.
struct SongPlayKey: View {
    var playing: Bool
    var accent: Color
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(accent)
            if playing {
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1.5).fill(.white).frame(width: 3.5, height: 12)
                    RoundedRectangle(cornerRadius: 1.5).fill(.white).frame(width: 3.5, height: 12)
                }
            } else {
                RoundedPlayTriangle()
                    .fill(.white)
                    .overlay(RoundedPlayTriangle().stroke(.white, style: StrokeStyle(lineWidth: 2, lineJoin: .round)))
                    .frame(width: 10, height: 12)
                    .offset(x: 1)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// One row of a ··· menu: 48 pt, hairline below, optional second line (Delete post: "The workout stays in your History.").
struct PostMenuRow: View {
    let title: String
    var detail: String? = nil
    var destructive = false
    var id: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.archivo(15, weight: .semibold)).foregroundStyle(destructive ? Color.signalDown : Color.inkPrimary)
                if let detail { Text(detail).font(.archivo(11)).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true) }
            }
            .padding(.horizontal, 14).padding(.vertical, detail == nil ? 0 : 8)
            .frame(maxWidth: .infinity, minHeight: SocialConfigStore.shared.current.card.menuRowHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(OreRowPressStyle())
        .accessibilityIdentifier(id ?? AX.row(title))
    }
}

/// The ··· menu as a popover anchored to the button (never a bottom sheet): `presentationCompactAdaptation(.popover)` keeps it a popover on iPhone.
struct PostMenuPopover<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .frame(width: SocialConfigStore.shared.current.card.menuWidth)
            .background(Color.canvasBg)
            .presentationCompactAdaptation(.popover)
    }
}

/// Workout length as the post prints it: "1:12:05" over an hour, "45:10" under.
enum PostTime {
    static func duration(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    static func ago(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "TODAY" }
        if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: y) { return "YESTERDAY" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        return days < 7 ? "\(days)D AGO" : date.formatted(.dateTime.day().month(.abbreviated)).uppercased()
    }
}
