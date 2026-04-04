import SwiftUI

struct MoreTabView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    WorkoutHistoryView()
                } label: {
                    Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                }
            }

            Section {
                NavigationLink {
                    // TODO: Profile view (Phase 9)
                    Text("Profile — Coming Soon")
                } label: {
                    Label("Profile", systemImage: "person.crop.circle")
                }

                NavigationLink {
                    // TODO: Settings view (Phase 12)
                    Text("Settings — Coming Soon")
                } label: {
                    Label("Settings", systemImage: "gear")
                }

                NavigationLink {
                    // TODO: Equipment profiles (Phase 10)
                    Text("Equipment Profiles — Coming Soon")
                } label: {
                    Label("Equipment", systemImage: "dumbbell")
                }
            }

            Section {
                NavigationLink {
                    // TODO: Tutorial (Phase 2 follow-up)
                    Text("Tutorial — Coming Soon")
                } label: {
                    Label("Tutorial / Help", systemImage: "questionmark.circle")
                }

                NavigationLink {
                    // TODO: Pulse+ (Phase 14)
                    Text("Pulse+ — Coming Soon")
                } label: {
                    Label("Pulse+", systemImage: "star.circle")
                }
            }
        }
        .navigationTitle("More")
    }
}
