import SwiftUI

extension View {
    /// Attaches an accessibility identifier only when one is given (UI-test hook; never changes layout or behaviour).
    @ViewBuilder
    func axID(_ id: String?) -> some View {
        if let id { accessibilityIdentifier(id) } else { self }
    }
}
