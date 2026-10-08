import SwiftUI

/// 6d — no friends. One line of fact, one of consequence, one action.
struct NoFriendsEmptyState: View {
    var onFindFriends: () -> Void = {}

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.inkPrimary.opacity(0.18))

            VStack(spacing: 6) {
                Text("No friends yet.")
                    .font(.archivo(20, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                Text("Sessions from people you follow appear here.")
                    .font(.archivo(13))
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
            }

            Button(action: onFindFriends) {
                Text("FIND FRIENDS")
                    .font(.archivo(14, weight: .black))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .frame(height: 44)
                    .padding(.horizontal, 24)
                    .background(Color.pumpAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 40)
    }
}

/// 6e — no friend challenges (the global card still shows above this, with a JOIN action).
struct NoChallengesEmptyState: View {
    var onCreateChallenge: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No friend challenges.")
                .font(.archivo(15, weight: .semibold))
                .foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 16)
            DashedAdd(title: "Create Challenge", action: onCreateChallenge)
                .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }
}

#Preview {
    VStack {
        NoFriendsEmptyState()
        Divider()
        NoChallengesEmptyState()
    }
}
