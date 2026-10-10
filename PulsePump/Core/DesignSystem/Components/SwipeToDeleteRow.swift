import SwiftUI

struct SwipeToDeleteRow<Content: View>: View {
    let onDeleteTapped: () -> Void
    var rowBackground: Color = Color.surf
    var resetReveal: Bool = false
    @ViewBuilder let content: () -> Content

    private let revealWidth: CGFloat = 72
    @State private var revealOffset: CGFloat = 0
    @GestureState private var dragDelta: CGFloat = 0

    private var currentOffset: CGFloat {
        max(-revealWidth, min(0, revealOffset + dragDelta))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Only render the delete zone when actually swiped — prevents it showing
            // through semi-transparent content during collapse/fade animations
            if currentOffset < 0 {
                Color.signalDown
                    .frame(width: revealWidth)
                    .overlay(
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                revealOffset = 0
                            }
                            onDeleteTapped()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete")
                        .accessibilityIdentifier(AX.swipeDelete)
                    )
            }

            content()
                .background(rowBackground)
                .offset(x: currentOffset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .updating($dragDelta) { value, state, _ in
                            let w = value.translation.width
                            guard abs(w) > abs(value.translation.height) * 1.5 else { return }
                            state = w
                        }
                        .onEnded { value in
                            let w = value.translation.width
                            guard abs(w) > abs(value.translation.height) else { return }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                revealOffset = (revealOffset + w) < -(revealWidth * 0.4) ? -revealWidth : 0
                            }
                        }
                )
        }
        .clipped()
        .onChange(of: resetReveal) { _, _ in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { revealOffset = 0 }
        }
    }
}
