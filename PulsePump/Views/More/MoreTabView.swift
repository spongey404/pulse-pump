import SwiftUI

struct MoreTabView: View {
    @Bindable var tutorialViewModel: TutorialViewModel

    var body: some View {
        List {
            Section {
                NavigationLink {
                    WorkoutHistoryView()
                } label: {
                    Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                }
            }

            Section("Tools") {
                NavigationLink {
                    PlateCalculatorView()
                } label: {
                    Label("Plate Calculator", systemImage: "scalemass")
                }

                NavigationLink {
                    WarmupGeneratorView()
                } label: {
                    Label("Warmup Generator", systemImage: "flame")
                }
            }

            Section {
                NavigationLink {
                    EquipmentProfilesView()
                } label: {
                    Label("Equipment Profiles", systemImage: "dumbbell")
                }

                NavigationLink {
                    ProfileView()
                } label: {
                    Label("Profile", systemImage: "person.crop.circle")
                }

                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }

            Section {
                Button {
                    tutorialViewModel.start()
                } label: {
                    Label("Tutorial / Help", systemImage: "questionmark.circle")
                }

                NavigationLink {
                    PulsePlusView()
                } label: {
                    Label("Pulse+", systemImage: "star.circle")
                }
            }
        }
        .navigationTitle("More")
    }
}
