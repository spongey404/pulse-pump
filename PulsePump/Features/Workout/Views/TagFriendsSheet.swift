import SwiftUI

/// Minimal friend picker backing the composer's (7a) TAG FRIENDS "ADD" chip. Not one of
/// the 17 spec'd screens — just enough UI to populate the post's `taggedUids`.
struct TagFriendsSheet: View {
    let alreadyTagged: [FirestoreUserProfile]
    let onDone: ([FirestoreUserProfile]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var friends: [FirestoreUserProfile] = []
    @State private var selectedUids: Set<String> = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if friends.isEmpty {
                    Text("No friends to tag yet")
                        .font(.archivo(14))
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(friends, id: \.uid) { friend in
                        Button {
                            if selectedUids.contains(friend.uid) {
                                selectedUids.remove(friend.uid)
                            } else {
                                selectedUids.insert(friend.uid)
                            }
                        } label: {
                            HStack {
                                Text(friend.shownName)
                                    .font(.archivo(15, weight: .semibold))
                                    .foregroundStyle(Color.inkPrimary)
                                Spacer()
                                if selectedUids.contains(friend.uid) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentInk)
                                }
                            }
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.canvasBg)
            .navigationTitle("Tag Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(friends.filter { selectedUids.contains($0.uid) })
                        dismiss()
                    }
                }
            }
        }
        .task {
            selectedUids = Set(alreadyTagged.map(\.uid))
            // Only friends (mutual follows) can be tagged.
            let social = SocialViewModel.shared
            await social.loadGraph()
            friends = social.friends
            isLoading = false
        }
    }
}
