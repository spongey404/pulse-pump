import SwiftUI

/// Bottom-docked action bar. Two styles: `.filled` is the 52pt accent slab (POST, DONE);
/// `.quiet` is a text-only row (`STEP 2 · INVITE FRIENDS … NEXT ›`) used where a filled CTA
/// would overstate the action. Callers place this via `.safeAreaInset(edge: .bottom)` per
/// the app's existing docked-bar convention (see `StartWorkoutDock`/`WorkoutBottomBar`).
struct DockedCTA: View {
    enum Style { case filled, quiet }

    var leadingText: String? = nil
    var trailingCount: String? = nil
    let primaryLabel: String
    var style: Style = .filled
    var secondaryIcon: String? = nil
    /// Accessibility identifiers for the UI tests (primary button / secondary icon button).
    var primaryID: String? = nil
    var secondaryID: String? = nil
    var secondaryAction: (() -> Void)? = nil
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.dsHairLine).frame(height: 1)
            HStack(spacing: 10) {
                switch style {
                case .filled:
                    Button(action: action) {
                        Text(primaryLabel)
                            .font(.archivo(15, weight: .black))
                            .tracking(0.5)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.oreAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .axID(primaryID)

                    if let secondaryIcon {
                        Button {
                            secondaryAction?()
                        } label: {
                            Image(systemName: secondaryIcon)
                                .font(.system(size: 18))
                                .foregroundStyle(Color.inkMuted)
                                .frame(width: 52, height: 52)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.ruleStrong, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .axID(secondaryID)
                    }

                case .quiet:
                    Button(action: action) {
                        HStack {
                            if let leadingText {
                                Text(leadingText)
                                    .font(.spaceMono(9))
                                    .tracking(1.5)
                                    .textCase(.uppercase)
                                    .foregroundStyle(Color.inkPrimary.opacity(0.75))
                            } else if let trailingCount {
                                Text(trailingCount)
                                    .font(.spaceMono(9))
                                    .tracking(1.5)
                                    .textCase(.uppercase)
                                    .foregroundStyle(Color.inkPrimary.opacity(0.75))
                            }
                            Spacer()
                            Text(primaryLabel)
                                .font(.archivo(14, weight: .black))
                                .tracking(0.5)
                                .foregroundStyle(Color.accentInk)
                        }
                        .frame(minHeight: 52)
                    }
                    .buttonStyle(.plain)
                    .axID(primaryID)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 26)
        }
        .background(Color.canvasBg)
    }
}

#Preview {
    VStack {
        Spacer()
        DockedCTA(primaryLabel: "POST", secondaryIcon: "ellipsis", secondaryAction: {}, action: {})
        DockedCTA(leadingText: "STEP 2 · INVITE FRIENDS", primaryLabel: "NEXT ›", style: .quiet, action: {})
        DockedCTA(trailingCount: "3 INVITED", primaryLabel: "DONE ›", style: .quiet, action: {})
    }
}
