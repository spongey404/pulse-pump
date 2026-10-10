import SwiftUI

/// Shown while auth state is unknown or the gate is working (wipe, cloud check).
struct SplashView: View {
    var body: some View {
        ZStack {
            Color.canvasBg.ignoresSafeArea()
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.pumpAccent).frame(width: 44, height: 44)
                    Image(systemName: "house.fill")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                }
                Text("PULSE/PUMP")
                    .font(.archivo(20, weight: .black)).tracking(1)
                    .foregroundStyle(Color.inkPrimary)
                ProgressView().tint(Color.accentInk)
            }
        }
        .accessibilityIdentifier(AX.gate.splash)
    }
}

/// Signed in on a new device: waiting for the initial pull.
struct RestoringView: View {
    var body: some View {
        ZStack {
            Color.canvasBg.ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().tint(Color.accentInk)
                Text("RESTORING YOUR DATA…")
                    .font(.spaceMono(11, weight: .bold)).tracking(1.5)
                    .foregroundStyle(Color.inkPrimary)
                Text("Your workouts and programs are coming back.")
                    .font(.archivo(13)).foregroundStyle(Color.inkMuted)
            }
        }
        .accessibilityIdentifier(AX.gate.restoring)
    }
}

/// Full-screen message with a retry and an escape hatch.
struct GateMessageView: View {
    let title: String
    let message: String
    let primary: (label: String, action: () -> Void)
    let secondary: (label: String, action: () -> Void)?

    var body: some View {
        ZStack {
            Color.canvasBg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.archivo(28, weight: .light)).foregroundStyle(Color.inkPrimary)
                Text(message)
                    .font(.archivo(14)).foregroundStyle(Color.inkMuted).lineSpacing(4)
                Spacer().frame(height: 14)
                Button(action: primary.action) {
                    Text(primary.label)
                        .font(.archivo(19, weight: .black)).tracking(2).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Color.pumpAccent).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                if let secondary {
                    Button(action: secondary.action) {
                        Text(secondary.label)
                            .font(.archivo(15, weight: .black)).tracking(1.5).foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity).frame(height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
        }
        .accessibilityIdentifier(AX.gate.message)
    }
}
