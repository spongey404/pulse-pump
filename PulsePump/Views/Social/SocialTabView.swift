import SwiftUI

struct SocialTabView: View {
    @State private var viewModel = SocialViewModel()

    var body: some View {
        ActivityFeedView(viewModel: viewModel)
    }
}
