import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Text("Programs")
                .tabItem {
                    Label("Programs", systemImage: "list.bullet.clipboard")
                }

            Text("Social")
                .tabItem {
                    Label("Social", systemImage: "person.2")
                }

            Text("Home")
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            Text("Body Map")
                .tabItem {
                    Label("Body Map", systemImage: "figure.stand")
                }

            Text("More")
                .tabItem {
                    Label("More", systemImage: "ellipsis")
                }
        }
    }
}

#Preview {
    ContentView()
}
