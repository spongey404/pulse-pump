import SwiftUI

/// Shared pieces of the Programs screens (Ore Programs).

/// Where the Programs flow can go.
enum ProgramRoute: Hashable {
    case startFrom
    case newProgram(choice: String)
    case editProgram(UUID)
    case program(UUID)
    case workout(UUID, edit: Bool)
    case addExercises(workout: UUID)
}

/// ‹ back, an accent kicker (Space Mono 9 / 2) over an Archivo 900 title, optional trailing content, and the strong rule under it.
struct ProgramPageHeader<Trailing: View>: View {
    let kicker: String
    let title: String
    var titleSize: CGFloat = 24
    let onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onBack) {
                    Text("‹").font(.archivo(22)).foregroundStyle(Color.inkSecondary).frame(width: 36, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel("Back").accessibilityIdentifier(AX.nav.back)
                VStack(alignment: .leading, spacing: 3) {
                    Text(kicker).font(.spaceMono(9)).tracking(2).foregroundStyle(Color.accentInk).lineLimit(1)
                    Text(title).font(.archivo(titleSize, weight: .black)).tracking(0.3).foregroundStyle(Color.inkPrimary).lineLimit(1)
                        .accessibilityIdentifier(AX.programs.pageTitle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailing()
            }
            .padding(.leading, 4).padding(.trailing, 16).padding(.top, 2).padding(.bottom, 10)
            Rectangle().fill(Color.ruleStrong).frame(height: 1)
        }
        .background(Color.canvasBg)
    }
}

extension ProgramPageHeader where Trailing == EmptyView {
    init(kicker: String, title: String, titleSize: CGFloat = 24, onBack: @escaping () -> Void) {
        self.init(kicker: kicker, title: title, titleSize: titleSize, onBack: onBack) { EmptyView() }
    }
}

/// "WORKOUTS ........ ROTATE IN ORDER": Space Mono 9, muted, 20 / 16 / 8 padding.
struct ProgramSectionRow: View {
    let left: String
    var right = ""
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(left)
            Spacer()
            Text(right)
        }
        .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
        .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 8)
    }
}

/// The docked primary of a page: 60 pt, radius 12, label left (Archivo 900 19) and › right. Accent with Stardust (a member's setting) when it
/// can act, grey when it cannot.
struct ProgramDockedButton: View {
    let title: String
    var enabled = true
    var id: String? = nil
    var height: CGFloat = 60
    var glyph = "›"
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            HStack {
                Text(title).font(.archivo(height >= 60 ? 19 : 17, weight: .black)).tracking(0.6)
                Spacer()
                Text(glyph).font(.archivo(height >= 60 ? 24 : 22, weight: .black))
            }
            .foregroundStyle(enabled ? Color.white : Color.inkMuted)
            .padding(.horizontal, 22).frame(height: height).frame(maxWidth: .infinity)
            .background { if enabled { AccentFill(priority: 10) } else { Color.surf2 } }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressOpacityButtonStyle())
        .axID(id)
    }
}

/// The bar a docked primary sits in: hairline above, 10 / 16 / 14.
struct ProgramDock<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 14).frame(maxWidth: .infinity)
            .background(Color.canvasBg)
            .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }
}

/// A 40 pt outlined text button (EDIT / DONE): radius 8, Archivo 900 13.
struct ProgramOutlineButton: View {
    let title: String
    var id: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.archivo(13, weight: .black)).tracking(0.6).foregroundStyle(Color.inkPrimary)
                .padding(.horizontal, 14).frame(height: 40).contentShape(Rectangle())
                .background(Color.surf, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1))
        }
        .buttonStyle(PressOpacityButtonStyle()).axID(id)
    }
}

/// A dashed full-width add row (+ ADD WORKOUT, + ADD EXERCISE): radius 12, Space Mono 9 bold.
struct ProgramDashedAdd: View {
    let title: String
    var height: CGFloat = 44
    var id: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkSecondary)
                .frame(maxWidth: .infinity).frame(height: height).contentShape(Rectangle())
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .buttonStyle(.plain).axID(id)
    }
}

/// The 7-cell week strip of the Programs list: M T W T F S S, training days tinted in the accent.
struct ProgramMiniWeek: View {
    let days: [Int]
    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(ProgramPlan.weekOrder.enumerated()), id: \.offset) { i, wd in
                let on = days.contains(wd)
                Text(ProgramPlan.weekLetters[i]).font(.spaceMono(9, weight: .bold))
                    .foregroundStyle(on ? Color.accentInk : Color.inkGhost)
                    .frame(width: 22, height: 22)
                    .background(on ? Color.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(on ? Color.accentInk.opacity(0.35) : Color.dsHairLine, lineWidth: 1))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trains " + ProgramPlan.weekdayText(ProgramPlan.ordered(days)))
    }
}

/// The week strip of a program page: 7 tiles, each the weekday (tiny) and its workout's number, 01 / 02 / 03; the next workout's day is
/// filled in the accent. Rest days are empty.
struct ProgramWeekTiles: View {
    let days: [Int]
    let workoutCount: Int
    /// The weekday the next workout falls on.
    let nextWeekday: Int?

    var body: some View {
        let assignment = ProgramPlan.assignment(days: days, workoutCount: workoutCount)
        HStack(spacing: 4) {
            ForEach(ProgramPlan.weekOrder, id: \.self) { wd in
                let idx = assignment[wd]
                let isNext = idx != nil && wd == nextWeekday
                VStack(spacing: 3) {
                    Text(String((ProgramPlan.weekdayNames[wd] ?? "").prefix(3))).font(.spaceMono(7)).tracking(1.5)
                        .foregroundStyle(isNext ? Color.white.opacity(0.85) : Color.inkMuted)
                    Text(idx.map { String(format: "%02d", $0 + 1) } ?? "—").font(.spaceMono(12, weight: .bold))
                        .foregroundStyle(isNext ? Color.white : (idx == nil ? Color.inkGhost : Color.inkPrimary))
                }
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(isNext ? Color.oreAccent : (idx == nil ? Color.clear : Color.surf), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(isNext ? Color.oreAccent : (idx == nil ? Color.dsHairLine : Color.ruleStrong), lineWidth: 1))
            }
        }
    }
}

/// A − / value / + stepper row of the workout editor: label left, 32 pt outlined squares around the value.
struct ProgramStepperRow: View {
    let label: String
    let value: String
    var minusID: String? = nil
    var plusID: String? = nil
    let onMinus: () -> Void
    let onPlus: () -> Void
    var body: some View {
        HStack {
            Text(label).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
            Spacer()
            HStack(spacing: 4) {
                box("−", minusID, onMinus)
                Text(value).font(.spaceMono(15, weight: .bold)).foregroundStyle(Color.inkPrimary).frame(minWidth: 64)
                box("+", plusID, onPlus)
            }
        }
        .frame(minHeight: 44)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func box(_ glyph: String, _ id: String?, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph).font(.spaceMono(14, weight: .bold)).foregroundStyle(Color.inkPrimary).frame(width: 32, height: 32)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.ruleStrong, lineWidth: 1)).contentShape(Rectangle())
        }
        .buttonStyle(PressOpacityButtonStyle()).axID(id)
    }
}
