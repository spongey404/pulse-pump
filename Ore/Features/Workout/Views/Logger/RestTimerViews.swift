import SwiftUI
import SwiftData

struct RestTimerModalView: View {
    let restTimer: RestTimerService
    let onClose: () -> Void

    @State private var cardScale: CGFloat = 0.88
    @State private var cardOpacity: Double = 0

    private let ringRadius: CGFloat = 96
    private var ringCircumference: CGFloat { 2 * .pi * ringRadius }
    private var ringSize: CGFloat { ringRadius * 2 + 20 }

    private let targetSeconds: Int = 150 // 2:30 default display

    var body: some View {
        ZStack(alignment: .center) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            // Card — pushed below the masthead bar
            VStack(spacing: 0) {
                // Ring
                ZStack {
                    // Track
                    Circle()
                        .stroke(Color.inkPrimary.opacity(0.14), lineWidth: 7)
                        .frame(width: ringSize, height: ringSize)
                    // Progress arc
                    Circle()
                        .trim(from: 0, to: restTimer.progress)
                        .stroke(Color.accentInk, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: restTimer.progress)

                    // Center content
                    VStack(spacing: 6) {
                        Text(restTimer.formattedTime)
                            .font(.spaceMono(64, weight: .bold))
                            .foregroundStyle(Color.inkPrimary)
                        Text("REST · TGT \(formattedTarget)")
                            .font(.spaceMono(9))
                            .foregroundStyle(Color.inkMuted)
                            .tracking(1.5)
                    }
                }
                .padding(.bottom, 20)

                // Adjust buttons
                HStack(spacing: 6) {
                    ForEach([("−15s", -15), ("+15s", 15), ("+30s", 30), ("+1m", 60)], id: \.0) { label, delta in
                        Button {
                            if restTimer.isRunning {
                                restTimer.adjust(by: delta)
                            } else {
                                // Start timer with the tapped duration
                                let secs = max(15, delta)
                                restTimer.start(seconds: secs)
                            }
                        } label: {
                            Text(label)
                                .font(.spaceMono(11, weight: .bold))
                                .foregroundStyle(Color.inkPrimary)
                                .tracking(0.5)
                                .frame(height: 34)
                                .frame(maxWidth: .infinity)
                                .background(Color.surf2)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.dsHairLine, lineWidth: 1)
                                )
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
                .padding(.bottom, 12)

                // Start / Skip button — label depends on running state
                Button {
                    if restTimer.isRunning {
                        restTimer.dismiss()
                        onClose()
                    } else {
                        restTimer.start(seconds: 90)
                    }
                } label: {
                    Text(restTimer.isRunning ? "SKIP REST" : "START TIMER")
                        .font(.archivo(17, weight: .black))
                        .foregroundStyle(.white)
                        .tracking(2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background { AccentFill() }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)
            .background(Color.surf)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.inkPrimary.opacity(0.14), lineWidth: 1)
            )
            .frame(width: 300)
            .padding(.horizontal, 24)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
            // Stay below masthead — offset down from center
            .offset(y: 30)
            .onAppear {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    cardScale = 1.0
                    cardOpacity = 1.0
                }
            }
        }
    }

    private var formattedTarget: String {
        let t = restTimer.totalSeconds > 0 ? restTimer.totalSeconds : targetSeconds
        let m = t / 60
        let s = t % 60
        return s == 0 ? "\(m):00" : "\(m):\(String(format: "%02d", s))"
    }
}

// MARK: - Exercise Substitution (retained from original)

struct RestTimerExpandedView: View {
    let restTimer: RestTimerService
    var body: some View {
        RestTimerModalView(restTimer: restTimer, onClose: { restTimer.dismiss() })
    }
}

struct RestTimerBanner: View {
    let restTimer: RestTimerService
    var body: some View { EmptyView() }
}
