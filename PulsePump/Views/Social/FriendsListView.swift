import SwiftUI

struct FriendsListView: View {
    // TODO: Backend integration needed for friend discovery and sync
    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(Color.pumpPrimary)
                    Text("Share Invite Link")
                }

                HStack {
                    Image(systemName: "person.crop.rectangle.stack")
                        .foregroundStyle(Color.pumpPrimary)
                    Text("Find from Contacts")
                }
            }

            Section("Friends") {
                ContentUnavailableView(
                    "No Friends Yet",
                    systemImage: "person.2.slash",
                    description: Text("Search by username or share your invite link to add friends.")
                )
            }
        }
        .searchable(text: $searchText, prompt: "Search by username")
    }
}
