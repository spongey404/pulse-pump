import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Profile  (More Screens.dc.html · 2a)

struct ProfileView: View {
    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { !$0.isDraft && $0.deletedAt == nil }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @State private var photoItem: PhotosPickerItem?
    @State private var navigateToEdit = false
    @State private var social = SocialViewModel.shared
    @State private var showFriends = false

    private var user: User? { users.first }

    var body: some View {
        VStack(spacing: 0) {
            MoreScreenHeader(title: "PROFILE", onBack: { (onBack ?? { dismiss() })() }) {
                Button { navigateToEdit = true } label: {
                    Text("EDIT")
                        .font(.spaceMono(9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.accentInk)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.accentInk.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if let user {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        avatarSection(user: user)
                        statsSection
                        followingSection
                        detailsSection(user: user)
                        Color.clear.frame(height: 32)
                    }
                }
            } else {
                Spacer()
                Text("NO PROFILE")
                    .font(.archivo(24, weight: .black))
                    .foregroundStyle(Color.inkFaint)
                Spacer()
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToEdit) {
            if let user { EditProfileView(user: user) }
        }
        .sheet(isPresented: $showFriends) {
            NavigationStack { FriendsListView(viewModel: social) }
        }
        .task { await social.loadGraph() }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    user?.avatarData = data
                    user?.markUpdated()
                }
            }
        }
    }

    // MARK: - Avatar

    private func avatarSection(user: User) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.surf2)
                            .frame(width: 72, height: 72)
                        if let data = user.avatarData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Text((user.name.prefix(1)).uppercased())
                                .font(.archivo(28, weight: .black))
                                .foregroundStyle(Color.inkPrimary)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.dsHairLine, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 0) {
                    Text(user.name)
                        .font(.archivo(22, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                    Text("@\(user.username.isEmpty ? user.name.lowercased().replacingOccurrences(of: " ", with: "") : user.username)")
                        .font(.spaceMono(10))
                        .tracking(0.5)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.top, 4)
                    Text(subtitle(user))
                        .font(.spaceMono(8))
                        .tracking(1.5)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.top, 6)
                }
                Spacer()
            }
            .padding(16)
        }
        .background(Color.surf)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func subtitle(_ user: User) -> String {
        var parts: [String] = []
        if let split = user.selectedSplit?.name, !split.isEmpty { parts.append(split.uppercased()) }
        parts.append(user.experienceLevel.displayName.uppercased())
        return parts.joined(separator: " · ")
    }

    // MARK: - Stats

    private var statsSection: some View {
        let cells: [(String, String)] = [
            ("\(workouts.count)", "WORKOUTS"),
            ("\(HomeWeekStats(workouts: workouts, templates: []).weekStreak) WK", "STREAK"),
            ("\(social.friendCount)", "FRIENDS"),
            ("\(social.fanCount)", "FOLLOWERS"),
        ]
        return HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { i, c in
                VStack(spacing: 4) {
                    Text(c.0)
                        .font(.spaceMono(20, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                    Text(c.1)
                        .font(.spaceMono(8))
                        .tracking(1.5)
                        .foregroundStyle(Color.inkMuted)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    if i > 0 { Rectangle().fill(Color.dsHairLine).frame(width: 1) }
                }
            }
        }
        .frame(height: 72)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: - Following

    private var followingSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("FRIENDS")
                    .font(.spaceMono(9))
                    .tracking(1.5)
                    .foregroundStyle(Color.inkMuted)
                Spacer()
                Text("\(social.friendCount)")
                    .font(.spaceMono(9))
                    .tracking(1.5)
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 6)

            ForEach(social.friends.prefix(3)) { friend in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.surf2)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Text(String(friend.displayName.prefix(1)).uppercased())
                                .font(.archivo(14, weight: .black))
                                .foregroundStyle(Color.inkMuted)
                        }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(friend.displayName)
                            .font(.archivo(14, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        Text("\(friend.totalWorkouts) WORKOUTS · \(friend.currentStreak) WK STREAK")
                            .font(.spaceMono(8))
                            .tracking(1)
                            .foregroundStyle(Color.inkMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("FRIEND")
                        .font(.spaceMono(8))
                        .tracking(1.2)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.ruleStrong, lineWidth: 1))
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }

            Button { showFriends = true } label: {
                HStack {
                    Text(social.friends.isEmpty ? "FIND FRIENDS" : "SEE ALL \(social.friendCount) · FIND FRIENDS")
                        .font(.spaceMono(9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.inkPrimary)
                    Spacer()
                    Text("›").font(.spaceMono(16)).foregroundStyle(Color.inkGhost)
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .contentShape(Rectangle())
                .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Details

    private func detailsSection(user: User) -> some View {
        VStack(spacing: 0) {
            MoreSectionLabel(title: "DETAILS", top: 16, bottom: 6)
            detailRow("EXPERIENCE", user.experienceLevel.displayName)
            detailRow("UNITS", user.unitPreference.displayName)
            detailRow("GENDER", user.gender.displayName)
            if user.weight > 0 {
                detailRow("BODY WEIGHT", user.unitPreference.format(user.weight), mono: true)   // stored kg, shown in pref
            }
            detailRow("MEMBER SINCE", memberSince(user: user), mono: true)
        }
    }

    private func detailRow(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.spaceMono(9))
                .tracking(1)
                .foregroundStyle(Color.inkMuted)
            Spacer()
            Text(value)
                .font(mono ? .spaceMono(13, weight: .bold) : .archivo(14, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func memberSince(user: User) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: user.createdAt ?? Date()).uppercased()
    }
}
