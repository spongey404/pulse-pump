import SwiftUI

struct SocialTabView: View {
    @State private var viewModel = SocialViewModel()

    var body: some View {
        NavigationStack {
            ActivityFeedView(viewModel: viewModel)
        }
    }
}
