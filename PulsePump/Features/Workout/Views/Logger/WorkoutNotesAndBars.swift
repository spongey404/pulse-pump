import SwiftUI
import SwiftData

struct WorkoutBottomBar: View {
    @Binding var searchText: String
    let onAddExercise: () -> Void
    var body: some View { EmptyView() }
}

struct WorkoutNotesRow: View {
    @Binding var notes: String
    @State private var isExpanded = false
    @FocusState private var isFocused: Bool

    var body: some View {
        if isExpanded {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Add a note for this workout...", text: $notes, axis: .vertical)
                    .lineLimit(2...6).focused($isFocused).font(.mono(15))
                Button("Done") { isExpanded = false; isFocused = false }
                    .font(Font.mono(11)).foregroundStyle(Color.accentInk)
            }
            .padding()
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onAppear { isFocused = true }
        } else {
            Button { isExpanded = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: notes.isEmpty ? "note.text.badge.plus" : "note.text")
                        .foregroundStyle(Color.inkMuted)
                    Text(notes.isEmpty ? "Add workout note" : notes)
                        .font(Font.mono(12)).foregroundStyle(Color.inkMuted).lineLimit(1)
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }
}

struct ExerciseNotesRow: View {
    @Binding var notes: String
    var lastSessionNote: String = ""
    @State private var isExpanded = false
    @FocusState private var isFocused: Bool

    private var placeholder: String {
        lastSessionNote.isEmpty ? "Add exercise note..." : "Last: \(lastSessionNote)"
    }

    var body: some View {
        if isExpanded {
            VStack(alignment: .leading, spacing: 6) {
                TextField(placeholder, text: $notes, axis: .vertical)
                    .lineLimit(2...6)
                    .focused($isFocused)
                    .font(.archivo(13))
                    .foregroundStyle(Color.inkPrimary)
                Button("DONE") { isExpanded = false; isFocused = false }
                    .font(.spaceMono(10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.accentInk)
            }
            .padding(.vertical, 2)
            .onAppear { isFocused = true }
        } else {
            Button { isExpanded = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: notes.isEmpty ? "note.text.badge.plus" : "note.text")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(notes.isEmpty ? Color.inkFaint : Color.inkMuted)
                    Text(notes.isEmpty ? placeholder : notes)
                        .font(.archivo(12))
                        .foregroundStyle(notes.isEmpty ? Color.inkFaint : Color.inkMuted)
                        .lineLimit(1)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }
}
