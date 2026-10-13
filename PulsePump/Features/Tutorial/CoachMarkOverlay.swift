import SwiftUI

// MARK: - Spotlight target registry
// Views mark themselves with `.tutorialTarget("id")`; ContentView resolves the bounds and
// hands the rect to `CoachMarkOverlay` (Tutorial design: `data-tid` + TutorialOverlay).

struct TutorialTargetKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func tutorialTarget(_ id: String) -> some View {
        anchorPreference(key: TutorialTargetKey.self, value: .bounds) { [id: $0] }
    }
}

// MARK: - Overlay

struct CoachMarkOverlay: View {
    @Bindable var viewModel: TutorialViewModel
    @Binding var selectedTab: Int
    /// Spotlight rect in the overlay's coordinate space; nil = card only.
    let targetRect: CGRect?
    let size: CGSize
    let safeTop: CGFloat

    private let pad: CGFloat = 6
    private let cardHeight: CGFloat = 215

    var body: some View {
        ZStack(alignment: .top) {
            if viewModel.isFinished {
                completion
            } else {
                dim
                progressStrip
                card
            }
        }
        .frame(width: size.width, height: size.height)
        .transition(.opacity)
        .onChange(of: viewModel.currentStep) { _, step in
            if step.requiredTab != selectedTab { withAnimation { selectedTab = step.requiredTab } }
        }
        .onAppear {
            let tab = viewModel.currentStep.requiredTab
            if tab != selectedTab { selectedTab = tab }
        }
    }

    // MARK: Dim + spotlight

    private var dimColor: Color { Color.inkPrimary.opacity(0.74) }

    private var dim: some View {
        ZStack {
            if let r = targetRect {
                let hole = r.insetBy(dx: -pad, dy: -pad)
                Rectangle()
                    .fill(dimColor)
                    .reverseMask {
                        RoundedRectangle(cornerRadius: 10).frame(width: hole.width, height: hole.height)
                            .position(x: hole.midX, y: hole.midY)
                    }
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentInk, lineWidth: 2)
                    .frame(width: hole.width, height: hole.height)
                    .position(x: hole.midX, y: hole.midY)
                    .allowsHitTesting(false)
            } else {
                Rectangle().fill(dimColor)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: targetRect)
    }

    // MARK: Progress strip (10 segments)

    private var progressStrip: some View {
        HStack(spacing: 3) {
            ForEach(TutorialStep.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s.rawValue <= viewModel.currentStep.rawValue ? Color.accentInk : Color.white.opacity(0.25))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, safeTop + 6)
        .allowsHitTesting(false)
    }

    // MARK: Tooltip card

    private var cardTop: CGFloat {
        let minTop = safeTop + 20
        guard let r = targetRect else { return size.height - cardHeight - 40 }
        let below = r.midY < size.height * 0.52
        return below
            ? min(r.maxY + pad + 10, size.height - cardHeight - 20)
            : max(r.minY - pad - cardHeight - 5, minTop)
    }

    private var card: some View {
        let step = viewModel.currentStep
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(step.phase.uppercased())
                    .font(.spaceMono(9, weight: .bold)).tracking(0.8)
                    .foregroundStyle(Color.accentInk)
                    .padding(.horizontal, 8).frame(height: 19)
                    .background(Color.accentSoft)
                    .clipShape(Capsule())
                Spacer()
                Text(String(format: "%02d / %d", step.rawValue + 1, TutorialStep.allCases.count))
                    .font(.spaceMono(9)).tracking(0.5).foregroundStyle(Color.inkMuted)
                Button("SKIP") { viewModel.skip() }
                    .font(.spaceMono(9)).tracking(0.8).foregroundStyle(Color.inkMuted)
                    .padding(.leading, 10)
                    .accessibilityIdentifier(AX.tutorial.skip)
            }
            .padding(.bottom, 7)

            Text(step.title)
                .font(.archivo(19, weight: .black))
                .foregroundStyle(Color.inkPrimary)
                .padding(.bottom, 4)
                .accessibilityIdentifier(AX.tutorial.card)
            Text(step.description)
                .font(.archivo(13))
                .foregroundStyle(Color.inkPrimary.opacity(0.7))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 11)

            Button {
                viewModel.advance()
            } label: {
                Text(step.cta.uppercased())
                    .font(.archivo(14, weight: .black)).tracking(1.4)
                    .foregroundStyle(Color.onAccent)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(Color.pumpAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AX.tutorial.next)
        }
        .padding(.top, 14).padding(.horizontal, 14).padding(.bottom, 12)
        .background(Color.canvasBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.ruleStrong, lineWidth: 1))
        .padding(.horizontal, 14)
        .offset(y: cardTop)
        .animation(.easeInOut(duration: 0.3), value: cardTop)
    }

    // MARK: Completion

    private var completion: some View {
        ZStack {
            Color(hex: "#1a1816").ignoresSafeArea()
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.pumpAccent)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.bottom, 28)
                Text("PULSE / PUMP")
                    .font(.spaceMono(11)).tracking(2.5)
                    .foregroundStyle(Color(hex: "#ece5d6").opacity(0.5))
                    .padding(.bottom, 12)
                Text("YOU'RE\nALL SET.")
                    .font(.archivo(44, weight: .black)).tracking(-1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: "#ece5d6"))
                    .padding(.bottom, 20)
                Text("Go build something worth logging.")
                    .font(.archivo(15))
                    .foregroundStyle(Color(hex: "#ece5d6").opacity(0.5))
                    .padding(.bottom, 44)
                Button { viewModel.complete() } label: {
                    Text("START TRAINING →")
                        .font(.archivo(18, weight: .black)).tracking(2)
                        .foregroundStyle(Color.onAccent)
                        .frame(maxWidth: .infinity).frame(height: 58)
                        .background(Color.pumpAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 14)
                Button { viewModel.start() } label: {
                    Text("REPLAY TUTORIAL")
                        .font(.spaceMono(10)).tracking(1)
                        .foregroundStyle(Color(hex: "#ece5d6").opacity(0.5))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 32)
        }
    }
}

private extension View {
    /// Punches `mask` out of the view (inverse mask).
    func reverseMask<M: View>(@ViewBuilder _ mask: () -> M) -> some View {
        self.mask {
            Rectangle().overlay { mask().blendMode(.destinationOut) }.compositingGroup()
        }
    }
}
