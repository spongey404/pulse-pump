import SwiftUI

/// 5a — Create challenge, step 1: name + metric + window. Tapping NEXT creates the
/// challenge (per spec, it already exists by step 2 — invites are added, not "created").
struct CreateChallengeStep1View: View {
    @Bindable var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var metric: ChallengeMetric = .totalVolume
    @Environment(\.weightUnit) private var weightUnit
    @State private var runsFor = "4weeks"
    @State private var customExercise = ""
    @State private var customCountBy = ""
    @State private var customUnit = ""
    @State private var isCreating = false
    @State private var createdChallengeId: String?
    @State private var showInvite = false
    @State private var showExercisePicker = false

    private let windows: [(key: String, label: String)] = [
        ("1week", "1 WEEK"), ("4weeks", "4 WEEKS"), ("restOfMonth", "REST OF MONTH"), ("1year", "1 YEAR"), ("custom", "CUSTOM"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Text("‹").font(Font.spaceMono(20)).foregroundStyle(Color.inkPrimary)
                }
                .buttonStyle(.plain)
                Text("NEW CHALLENGE").font(.archivo(22, weight: .black)).tracking(0.5).foregroundStyle(Color.inkPrimary)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 0.5) }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        TextField("August Volume", text: $name)
                            .font(.archivo(20, weight: .bold))
                            .foregroundStyle(Color.inkPrimary)
                    }
                    .padding(.top, 16)
                    .frame(minHeight: 44, alignment: .bottom)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.ruleStrong).frame(height: 1) }

                    SectionLabel(title: "Measured By").padding(.top, 24).padding(.bottom, 8)
                    ForEach(ChallengeMetric.allCases) { m in
                        metricRow(m)
                    }

                    if metric == .custom {
                        VStack(spacing: 0) {
                            customCallout
                                .padding(.bottom, 14)
                            Text("CUSTOM MEASUREMENT")
                                .font(Font.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                                .padding(.bottom, 10)
                            Button { showExercisePicker = true } label: {
                                customFieldRow(label: "EXERCISE", value: customExercise.isEmpty ? "Bench Press" : customExercise)
                            }
                            .buttonStyle(.plain)
                            customField(label: "COUNT BY", value: $customCountBy, placeholder: "Heaviest lift")
                            customField(label: "UNIT", value: $customUnit, placeholder: weightUnit.label)
                        }
                        .padding(.top, 14)
                    }

                    SectionLabel(title: "Runs For").padding(.top, 24).padding(.bottom, 10)
                    FlowLayout(spacing: 8) {
                        ForEach(windows, id: \.key) { w in
                            FilterChip(title: w.label, isSelected: runsFor == w.key) { runsFor = w.key }
                        }
                    }

                    Text("EVERY METRIC EXCEPT CUSTOM IS SCORED FROM LOGGED SESSIONS · NOTHING TO ENTER BY HAND")
                        .font(Font.spaceMono(9)).tracking(1.2).foregroundStyle(Color.inkMuted)
                        .padding(.top, 24)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.canvasBg)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) {
            DockedCTA(leadingText: "STEP 2 · INVITE FRIENDS", primaryLabel: isCreating ? "…" : "NEXT ›", style: .quiet) {
                createAndAdvance()
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
        }
        .navigationDestination(isPresented: $showInvite) {
            InviteFriendsView(viewModel: viewModel, challengeId: createdChallengeId ?? "", challengeName: name, metricLabel: metric.displayName, windowLabel: windows.first { $0.key == runsFor }?.label ?? "")
        }
        // Same presentation the logging screen uses for its exercise picker
        // (`ActiveWorkoutView`) — a full screen, not a sheet.
        .fullScreenCover(isPresented: $showExercisePicker) {
            ExercisePickerView(title: "SELECT EXERCISE") { exercises in
                if let first = exercises.first { customExercise = first.name }
                showExercisePicker = false
            }
        }
    }

    /// "Pump can't score this one" — read before the custom fields, since selecting Custom
    /// otherwise reads as if Pump will still score it automatically like the other 5 metrics.
    private var customCallout: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.inkPrimary)
                .padding(.top, 1)
            Text("Pump can't score this one. Everyone in the challenge types their own number in, and you'll see who entered what.")
                .font(.archivo(12))
                .lineSpacing(3)
                .foregroundStyle(Color.inkPrimary)
        }
        .padding(11)
        .background(Color.surf2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func customFieldRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
            Spacer()
            HStack(spacing: 4) {
                Text(value).font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                Text("›").font(Font.spaceMono(12)).foregroundStyle(Color.inkMuted)
            }
        }
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func metricRow(_ m: ChallengeMetric) -> some View {
        let selected = metric == m
        return Button { metric = m } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.displayName).font(.archivo(16, weight: selected ? .bold : .regular)).foregroundStyle(Color.inkPrimary)
                    Text("\(m.unitLabel(weightUnit)) · \(m.rule)").font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
                }
                Spacer()
                if selected {
                    Text("✓").font(Font.spaceMono(13, weight: .bold)).foregroundStyle(Color.accentInk)
                }
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 56)
            .background(selected ? Color.activeRowBg : Color.clear)
            .overlay(alignment: .leading) {
                if selected { Rectangle().fill(Color.pumpAccent).frame(width: 2) }
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func customField(label: String, value: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label).font(Font.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted)
            Spacer()
            TextField(placeholder, text: value)
                .font(.archivo(15, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func createAndAdvance() {
        isCreating = true
        Task {
            let id = await viewModel.createChallenge(
                name: name.trimmingCharacters(in: .whitespaces),
                metric: metric,
                startDate: Date(),
                endDate: Date().addingTimeInterval(28 * 24 * 3600),
                runsFor: runsFor,
                isGlobal: false,
                customExercise: metric == .custom ? customExercise : nil,
                customCountBy: metric == .custom ? customCountBy : nil,
                customUnit: metric == .custom ? customUnit : nil
            )
            isCreating = false
            createdChallengeId = id
            showInvite = id != nil
        }
    }
}
