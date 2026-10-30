import SwiftUI
import UIKit

/// Reports where the scroll view it sits in is scrolled to. SwiftUI gives no scroll offset before iOS 18,
/// and measuring a view's frame does not update while scrolling, so this watches the underlying
/// `UIScrollView` directly.
/// - `onChange`: how far the content is dragged down past its top (0 otherwise), for pull-to-search.
/// - `onDepth`: how far down from the top the content is scrolled (0 at the top).
struct ScrollPullObserver: UIViewRepresentable {
    let onChange: (CGFloat) -> Void
    var onDepth: ((CGFloat) -> Void)? = nil

    func makeUIView(context: Context) -> Probe { Probe() }
    func updateUIView(_ view: Probe, context: Context) {
        view.onChange = onChange
        view.onDepth = onDepth
    }

    final class Probe: UIView {
        var onChange: ((CGFloat) -> Void)?
        var onDepth: ((CGFloat) -> Void)?
        private var observation: NSKeyValueObservation?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            backgroundColor = .clear
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            observation = nil
            guard window != nil else { return }
            var ancestor = superview
            while let view = ancestor, !(view is UIScrollView) { ancestor = view.superview }
            guard let scroll = ancestor as? UIScrollView else { return }
            observation = scroll.observe(\.contentOffset, options: [.new]) { [weak self] scroll, _ in
                let fromTop = scroll.contentOffset.y + scroll.adjustedContentInset.top
                MainActor.assumeIsolated {
                    self?.onChange?(max(0, -fromTop))
                    self?.onDepth?(max(0, fromTop))
                }
            }
        }
    }
}
