import SwiftUI

// MARK: - 16 Lock screen accessories  (Pump Widgets.dc.html · w16)
// Monochrome, white-on-dark. Not PWFamily-sized: each view is drawn at the design's own size.

private let lockDim = Color.white.opacity(0.7)
private let lockDimmer = Color.white.opacity(0.8)

/// 02 · CIRCULAR — streak "12 DAYS".
struct LockCircularStreak: View {
    let snap: PumpWidgetSnapshot
    /// The gallery draws its own disc; WidgetKit supplies AccessoryWidgetBackground, so the host turns this off.
    var drawsDisc = true

    init(snap: PumpWidgetSnapshot, drawsDisc: Bool = true) { self.snap = snap; self.drawsDisc = drawsDisc }

    var body: some View {
        VStack(spacing: 0) {
            Text("\(snap.streak)").pwMono(24, bold: true, color: .white).lineLimit(1).minimumScaleFactor(0.6)
            Text("DAYS").pwMono(7, color: lockDim, tracking: 1.2)
        }
        .frame(width: 72, height: 72)
        .background { if drawsDisc { Circle().fill(Color.white.opacity(0.16)) } }
    }
}

/// 11 · CIRCULAR — weekly goal "4/5" + five squares.
struct LockCircularGoal: View {
    let snap: PumpWidgetSnapshot
    var drawsDisc = true

    init(snap: PumpWidgetSnapshot, drawsDisc: Bool = true) { self.snap = snap; self.drawsDisc = drawsDisc }

    var body: some View {
        VStack(spacing: 5) {
            Text("\(snap.sessionsThisWeek)/\(snap.sessionGoal)").pwMono(18, bold: true, color: .white)
                .lineLimit(1).minimumScaleFactor(0.6)
            HStack(spacing: 2) {
                ForEach(0..<max(snap.sessionGoal, 0), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1).fill(Color.white)
                        .opacity(i < snap.sessionsThisWeek ? 1 : 0.3)
                        .frame(width: 5, height: 5)
                }
            }
        }
        .frame(width: 72, height: 72)
        .background { if drawsDisc { Circle().fill(Color.white.opacity(0.16)) } }
    }
}

private struct LockRectFrame<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 3, content: content)
            .padding(.horizontal, 2).padding(.vertical, 6)
            .frame(width: 172, height: 76, alignment: .leading)
    }
}

/// 01 · RECTANGULAR — next workout.
struct LockRectNext: View {
    let snap: PumpWidgetSnapshot
    init(snap: PumpWidgetSnapshot) { self.snap = snap }
    var body: some View {
        LockRectFrame {
            Text("NEXT · \(snap.nextDay)").pwMono(8, color: lockDim, tracking: 1.2)
            Text(snap.nextName.isEmpty ? "—" : snap.nextName.uppercased()).pwDisplay(18, tracking: 0, color: .white)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text("\(snap.nextExercises) EX · ~\(snap.nextEstMinutes) MIN").pwMono(9, color: lockDimmer, tracking: 1)
        }
    }
}

/// 03 · RECTANGULAR — weekly volume (sets).
struct LockRectVolume: View {
    let snap: PumpWidgetSnapshot
    init(snap: PumpWidgetSnapshot) { self.snap = snap }
    private var delta: Double? {
        let last = snap.fixed.setsLastWeekSameDay
        guard last > 0 else { return nil }
        return Double(snap.fixed.setsThisWeek - last) / Double(last) * 100
    }
    var body: some View {
        LockRectFrame {
            Text("SETS · WK \(snap.weekNumber)").pwMono(8, color: lockDim, tracking: 1.2)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(snap.fixed.setsThisWeek)").pwMono(24, bold: true, color: .white)
                if let d = delta {
                    Text((d >= 0 ? "▲ " : "▼ ") + PWFormat.signedPct(d)).pwMono(11, bold: true, color: .white)
                }
            }
            Text("VS \(snap.fixed.setsLastWeekSameDay) LAST WK").pwMono(9, color: lockDimmer, tracking: 1)
        }
    }
}

/// 06 · RECTANGULAR — PR watch (closest lift to its record).
struct LockRectPR: View {
    let snap: PumpWidgetSnapshot
    init(snap: PumpWidgetSnapshot) { self.snap = snap }
    private var lift: PWLift? {
        snap.fixed.prLifts.filter { $0.pr > 0 }.max { $0.e1rm / $0.pr < $1.e1rm / $1.pr } ?? snap.fixed.prLifts.first
    }
    var body: some View {
        LockRectFrame {
            Text("PR WATCH").pwMono(8, color: lockDim, tracking: 1.2)
            Text(lift?.name ?? "—").pwBody(14, color: .white).lineLimit(1)
            HStack(spacing: 0) {
                Text(lift.map { String(format: "%.1f", snap.unit.display($0.e1rm)) } ?? "—").pwMono(11, bold: true, color: .white)
                Text(" / ").pwMono(11, color: .white)
                Text(lift.map { String(format: "%.1f", snap.unit.display($0.pr)) } ?? "—").pwMono(11, color: .white)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.white).frame(height: 1.5).offset(y: 2) }
                Text(" \(snap.unit.label)").pwMono(11, color: .white)
            }
        }
    }
}

/// 01 · INLINE — "MON 5 · PUSH DAY NEXT".
struct LockInlineNext: View {
    let snap: PumpWidgetSnapshot
    init(snap: PumpWidgetSnapshot) { self.snap = snap }
    private var dateShort: String {
        let parts = snap.fixed.nextDate.split(separator: " ")
        return parts.count >= 2 ? "\(parts[0]) \(parts[1])" : snap.nextDay
    }
    var body: some View {
        Text("\(dateShort) · \(snap.nextName.isEmpty ? "—" : snap.nextName.uppercased()) NEXT")
            .pwMono(12, color: .white, tracking: 1)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(height: 76, alignment: .leading)
    }
}

enum LockScreenWidgets {
    static let blurb = "Accessory families render monochrome, so meaning is carried by numbers and squares. Circular uses the system accessory backing."

    static var gallery: [PWGalleryItem] {
        [
            PWGalleryItem("02 · CIRCULAR", .small, isLock: true, customSize: CGSize(width: 72, height: 72)) { AnyView(LockCircularStreak(snap: $0)) },
            PWGalleryItem("11 · CIRCULAR", .small, isLock: true, customSize: CGSize(width: 72, height: 72)) { AnyView(LockCircularGoal(snap: $0)) },
            PWGalleryItem("01 · RECTANGULAR", .small, isLock: true, customSize: CGSize(width: 172, height: 76)) { AnyView(LockRectNext(snap: $0)) },
            PWGalleryItem("03 · RECTANGULAR", .small, isLock: true, customSize: CGSize(width: 172, height: 76)) { AnyView(LockRectVolume(snap: $0)) },
            PWGalleryItem("06 · RECTANGULAR", .small, isLock: true, customSize: CGSize(width: 172, height: 76)) { AnyView(LockRectPR(snap: $0)) },
            PWGalleryItem("01 · INLINE", .small, isLock: true, customSize: CGSize(width: 260, height: 76)) { AnyView(LockInlineNext(snap: $0)) },
        ]
    }
}
