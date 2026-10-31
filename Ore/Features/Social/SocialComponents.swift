import SwiftUI

/// Small pill button used across the Social screens (FOLLOW, ACCEPT, IGNORE, UNFOLLOW, INVITE ...).
/// Filled = the primary action; outlined = the quiet one.
struct SocialPill: View {
    enum Style { case filled, outlined }

    let title: String
    var style: Style = .filled
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Font.spaceMono(9, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(style == .filled ? Color.white : Color.inkMuted)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background { if style == .filled { AccentFill() } }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(style == .outlined ? Color.ruleStrong : Color.clear, lineWidth: 1))
                .opacity(isDisabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityIdentifier(AX.social.pill(title))
    }
}

/// Back chevron + title row used by the pushed Social screens.
struct SocialScreenHeader<Trailing: View>: View {
    let title: String
    var onBack: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            if let onBack {
                Button(action: onBack) { Text("‹").font(Font.spaceMono(20)).foregroundStyle(Color.inkPrimary) }
                    .buttonStyle(.plain)
                    .frame(minWidth: 28, minHeight: 44)
                    .accessibilityLabel("Back")
                    .accessibilityIdentifier(AX.nav.back)
            }
            Text(title).font(.archivo(22, weight: .black)).tracking(0.5).foregroundStyle(Color.inkPrimary).lineLimit(1)
                .accessibilityIdentifier(AX.nav.title(title))
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 0.5) }
    }
}

extension SocialScreenHeader where Trailing == EmptyView {
    init(title: String, onBack: (() -> Void)?) {
        self.init(title: title, onBack: onBack, trailing: { EmptyView() })
    }
}

/// Skeleton rows shaped like the content they stand in for (the design asks for these instead of spinners).
struct SkeletonRows: View {
    var count = 3
    var rowHeight: CGFloat = 56

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10).fill(Color.surf2).frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.surf2).frame(width: 140, height: 10)
                        RoundedRectangle(cornerRadius: 3).fill(Color.surf2).frame(width: 90, height: 8)
                    }
                    Spacer()
                }
                .frame(minHeight: rowHeight)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A feed-post-shaped skeleton for the first load of the feed.
struct FeedSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Circle().fill(Color.surf2).frame(width: 38, height: 38)
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.surf2).frame(width: 120, height: 10)
                            RoundedRectangle(cornerRadius: 3).fill(Color.surf2).frame(width: 180, height: 8)
                        }
                    }
                    Rectangle().fill(Color.surf2).frame(height: 200)
                    HStack(spacing: 6) {
                        ForEach(0..<4, id: \.self) { _ in RoundedRectangle(cornerRadius: 4).fill(Color.surf2).frame(height: 36) }
                    }
                }
                .padding(16)
                Rectangle().fill(Color.ruleStrong).frame(height: 1)
            }
        }
        .accessibilityHidden(true)
    }
}

/// An error line with a retry action (never silent, never demo data).
struct RetryNotice: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(message).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary)
            SocialPill(title: "RETRY", style: .outlined, action: retry)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
