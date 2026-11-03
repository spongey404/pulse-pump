import SwiftUI
import SwiftData

/// Challenge a friend from their profile: WHAT COUNTS, (for Beat a PR) BEAT and the lifts, HOW LONG, SEND CHALLENGE.
struct DirectChallengeSheet: View {
    let friendUid: String
    let friendName: String
    let theirBest: [String: Double]
    var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var unit
    @Query private var exercises: [Exercise]
    @State private var model = DirectChallengeModel()
    @State private var sent: DirectChallengeModel?
    @State private var sending = false
    @State private var showAny = false
    @State private var anyQuery = ""

    /// Best weight per exercise name from this device's History (the PR the chips show).
    private var myBest: [String: Double] {
        var out: [String: Double] = [:]
        for e in exercises { if let m = e.finalLogs.flatMap(\.workingSets).map(\.weight).max(), m > 0 { out[e.name] = m } }
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.inkGhost).frame(width: 36, height: 4).padding(.top, 8).padding(.bottom, 10)
            if let sent { sentView(sent) } else { form }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .presentationDetents([.large])
    }

    // MARK: Form

    private var form: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Challenge \(friendName)").font(.archivo(22, weight: .black)).foregroundStyle(Color.inkPrimary)
                Spacer()
                Button("Close") { dismiss() }.font(.archivo(14, weight: .semibold)).foregroundStyle(Color.accentInk)
            }
            .padding(.horizontal, 16).padding(.bottom, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    label("WHAT COUNTS").padding(.bottom, 8)
                    ForEach(DirectChallengeModel.Count.allCases, id: \.self) { c in countRow(c) }
                    if model.count == .beatPR { beatPR }
                    label("HOW LONG").padding(.top, 14).padding(.bottom, 8)
                    SegmentedChoice(options: DirectChallengeModel.Length.allCases.map { ($0.rawValue, $0) }, selection: $model.length).padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            }
            DockedPrimaryButton(title: sending ? "SENDING" : "SEND CHALLENGE", disabled: !model.canSend || sending, id: "challenge.send", action: send)
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 14)
        }
    }

    private func label(_ t: String) -> some View { ComposerLabel(text: t).padding(.horizontal, 16).padding(.top, 4) }

    private func countRow(_ c: DirectChallengeModel.Count) -> some View {
        Button { model.count = c } label: {
            HStack {
                Text(c.rawValue).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
                Spacer()
                if model.count == c { Text("✓").font(.spaceMono(14, weight: .bold)).foregroundStyle(Color.accentInk) }
            }
            .padding(.horizontal, 16).frame(minHeight: 48).contentShape(Rectangle())
            .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        }
        .buttonStyle(.plain).accessibilityIdentifier(AX.row(c.rawValue))
    }

    @ViewBuilder private var beatPR: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ComposerLabel(text: "BEAT")
                Spacer()
                SegmentedChoice(options: [("YOUR OWN PR", DirectChallengeModel.Beat.own), ("\(friendName.uppercased())'S PR", .theirs)], selection: $model.beat)
            }
            HStack { ComposerLabel(text: "YOUR BEST LIFTS"); Spacer(); ComposerLabel(text: "\(model.lifts.count) PICKED") }
            FlowLayout(spacing: 6) {
                ForEach(DirectChallengeModel.strongest(myBest), id: \.name) { l in liftChip(l.name, pr: l.kg) }
                ForEach(model.lifts.filter { n in !DirectChallengeModel.strongest(myBest).contains { $0.name == n } }, id: \.self) { n in liftChip(n, pr: myBest[n]) }
                Button { showAny = true } label: {
                    Text("+ ANY EXERCISE").font(.spaceMono(9, weight: .bold)).tracking(1.2).foregroundStyle(Color.inkMuted).padding(.horizontal, 12).frame(height: 34)
                        .overlay(Capsule().strokeBorder(Color.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                }.buttonStyle(.plain)
            }
            if model.beat == .own {
                HStack {
                    ComposerLabel(text: "ADD TO YOUR BEST")
                    Spacer()
                    SegmentedChoice(options: DirectChallengeModel.increments.map { ("+\(unit.number($0)) \(unit.label)", $0) }, selection: $model.increment)
                }
            } else {
                vsTable
                Text(DirectChallengeModel.theirPRRule).font(.archivo(13)).foregroundStyle(Color.inkSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16).padding(.top, 14)
        .sheet(isPresented: $showAny) { anyExercise }
    }

    private func liftChip(_ name: String, pr: Double?) -> some View {
        let on = model.lifts.contains(name)
        return Button { model.toggle(name) } label: {
            HStack(spacing: 6) {
                Text(name.exerciseTitleCase).font(.archivo(13, weight: .semibold))
                if let pr { Text("\(unit.number(pr))").font(.spaceMono(10, weight: .bold)).foregroundStyle(on ? .white.opacity(0.8) : Color.inkMuted) }
            }
            .foregroundStyle(on ? Color.white : Color.inkPrimary).padding(.horizontal, 12).frame(height: 34)
            .background(Capsule().fill(on ? Color.oreAccent : Color.surf2))
        }
        .buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
    }

    private var vsTable: some View {
        VStack(spacing: 0) {
            HStack { Text("LIFT").frame(maxWidth: .infinity, alignment: .leading); Text("YOU").frame(width: 64, alignment: .trailing); Text(friendName.uppercased()).frame(width: 64, alignment: .trailing).lineLimit(1) }
                .font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted).padding(.vertical, 8)
            ForEach(model.vsRows(mine: myBest, theirs: theirBest), id: \.lift) { r in
                HStack {
                    Text(r.lift.exerciseTitleCase).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary).frame(maxWidth: .infinity, alignment: .leading)
                    Text(r.you.map { unit.number($0) } ?? "—").foregroundStyle(r.youHigher ? Color.signalUp : Color.inkPrimary).frame(width: 64, alignment: .trailing)
                    Text(r.them.map { unit.number($0) } ?? "—").foregroundStyle(r.themHigher ? Color.signalUp : Color.inkPrimary).frame(width: 64, alignment: .trailing)
                }
                .font(.spaceMono(13, weight: .bold)).frame(minHeight: 40).overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }
        }
    }

    private var anyExercise: some View {
        NavigationStack {
            List(exercises.filter { anyQuery.isEmpty || $0.name.localizedCaseInsensitiveContains(anyQuery) }.prefix(60), id: \.id) { e in
                Button { if !model.lifts.contains(e.name) { model.toggle(e.name) }; showAny = false } label: {
                    Text(e.name.exerciseTitleCase).font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary).frame(minHeight: 40)
                }
            }
            .searchable(text: $anyQuery).navigationTitle("Any exercise").navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Sent

    private func sentView(_ m: DirectChallengeModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("✓ SENT").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.signalUp)
            Text(m.count == .beatPR ? "BEAT A PR" : m.count.rawValue.uppercased()).font(.archivo(24, weight: .black)).foregroundStyle(Color.inkPrimary)
            Text("Starts when \(friendName) accepts and runs for \(m.length.rawValue.lowercased()). Only sessions logged after that count.")
                .font(.archivo(15)).foregroundStyle(Color.inkSecondary).fixedSize(horizontal: false, vertical: true)
            Spacer()
            DockedPrimaryButton(title: "DONE", id: "challenge.done") { dismiss() }.padding(.bottom, 14)
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }

    private func send() {
        sending = true
        let draft = model.draft(me: viewModel.myName, them: friendName)
        Task {
            if let id = await viewModel.createChallenge(draft),
               let challenge = viewModel.myChallenges.first(where: { $0.id == id }),
               await viewModel.sendChallengeInvite(challenge: challenge, toUid: friendUid) {
                PendingDirectChallenges.record(uid: friendUid, length: model.length, challengeId: id)
                sent = model
            }
            sending = false
        }
    }
}
