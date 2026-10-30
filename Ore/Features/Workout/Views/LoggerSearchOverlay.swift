import SwiftUI

/// Pull the workout down from the top (like Spotlight on the Home Screen) to find an exercise that is
/// already in the session without scrolling to it: type any word of its name and tap the match to jump to
/// its card. (Adding a new exercise is the + in the header.)
struct LoggerSearchOverlay: View {
    /// The workout's exercises, in order: matches jump to their card.
    let workoutEntries: [(id: UUID, exerciseId: UUID, name: String)]
    let onJump: (UUID) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @State private var appeared = false
    @FocusState private var focused: Bool

    private var matches: [(id: UUID, name: String)] {
        ExerciseSearch.workoutMatches(names: workoutEntries.map(\.name), query: query)
            .map { (workoutEntries[$0].id, workoutEntries[$0].name) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .opacity(appeared ? 1 : 0)
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                searchField
                    .tutorialTarget("tutorial.search-field")
                Rectangle().fill(Color.dsHairLine).frame(height: 1)
                resultsList
            }
            .tutorialTarget("tutorial.search-panel")
            .background(Color.canvasBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.inkPrimary.opacity(0.14), lineWidth: 1))
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .offset(y: appeared ? 0 : -260)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) { appeared = true }
            // The keyboard is up as soon as the panel opens, ready to type. (The tutorial types for the user
            // and keeps the keyboard away so the results stay in view.)
            if !TutorialMode.isRunning { raiseKeyboard() }
        }
        // The tutorial types the search for the user.
        .onReceive(NotificationCenter.default.publisher(for: .tutorialFillSearch)) { note in
            if let text = note.object as? String { query = text }
        }
    }

    /// Focus can be refused while the panel is still sliding in, so ask again until the field has it.
    private func raiseKeyboard(attempt: Int = 0) {
        focused = true
        guard attempt < 4 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            if !focused { raiseKeyboard(attempt: attempt + 1) }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Color.inkMuted)
            TextField("Search your workout…", text: $query)
                .font(.archivo(16))
                .foregroundStyle(Color.inkPrimary)
                .focused($focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier(AX.workout.searchField)
            Button("CANCEL", action: onClose)
                .font(.spaceMono(9, weight: .bold)).tracking(0.8)
                .foregroundStyle(Color.inkMuted)
                .accessibilityIdentifier(AX.workout.searchClose)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        // Tapping anywhere along the bar starts typing, not just on the text itself.
        .background(Color.clear.contentShape(Rectangle()).onTapGesture { focused = true })
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                hint("TYPE A NAME · ANY WORD WORKS")
            } else if matches.isEmpty {
                hint("NOTHING IN YOUR WORKOUT MATCHES")
            } else {
                ForEach(Array(matches.enumerated()), id: \.element.id) { index, item in
                    workoutRow(item)
                        .tutorialTarget("tutorial.search-workout-result", enabled: index == 0)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.spaceMono(9)).tracking(1)
            .foregroundStyle(Color.inkFaint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
    }

    /// An exercise already in the workout: tapping it scrolls straight to its card.
    private func workoutRow(_ item: (id: UUID, name: String)) -> some View {
        Button { onJump(item.id) } label: {
            HStack(spacing: 10) {
                Text(item.name)
                    .font(.archivo(15, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                Spacer()
                Text("JUMP")
                    .font(.spaceMono(9, weight: .bold)).tracking(1)
                    .foregroundStyle(Color.accentInk)
                Image(systemName: "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.accentInk)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AX.workout.searchInWorkoutRow(item.name))
    }
}
