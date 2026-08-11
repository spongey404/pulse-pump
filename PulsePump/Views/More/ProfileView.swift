import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    var onBack: (() -> Void)? = nil
    @Query private var users: [User]
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { !$0.isDraft }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @State private var photoItem: PhotosPickerItem?
    @State private var navigateToEdit = false

    private var user: User? { users.first }

    var body: some View {
        VStack(spacing: 0) {
            profileHeader

            if let user {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        avatarSection(user: user)
                        statsSection
                        detailsSection(user: user)
                        Color.clear.frame(height: 40)
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
        .navigationDestination(isPresented: $navigateToEdit) {
            if let user { EditProfileView(user: user) }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    user?.avatarData = data
                    user?.updatedAt = Date()
                }
            }
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                            .frame(width: 36, height: 36)
                            .background(Color.surf2)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                Text("PROFILE")
                    .font(.archivo(24, weight: .black))
                    .tracking(0.5)
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button { navigateToEdit = true } label: {
                    Text("EDIT")
                        .font(.spaceMono(9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.accentInk)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.accentInk.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
        .background(Color.canvasBg)
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

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.archivo(22, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                    Text("@\(user.username.isEmpty ? user.name.lowercased().replacingOccurrences(of: " ", with: "") : user.username)")
                        .font(.spaceMono(10))
                        .tracking(0.5)
                        .foregroundStyle(Color.inkMuted)
                    if let split = user.selectedSplit {
                        Text(split.name.uppercased())
                            .font(.spaceMono(8))
                            .tracking(1.5)
                            .foregroundStyle(Color.accentInk)
                            .padding(.top, 2)
                    } else {
                        Text(user.experienceLevel.displayName.uppercased())
                            .font(.spaceMono(8))
                            .tracking(1.5)
                            .foregroundStyle(Color.inkMuted)
                            .padding(.top, 2)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
        .background(Color.surf)
    }

    // MARK: - Stats

    private var statsSection: some View {
        let cal = Calendar.current
        let thisYear = cal.component(.year, from: Date())
        let thisYearCount = workouts.filter { cal.component(.year, from: $0.date) == thisYear }.count
        let streak = StreakCalculator.currentStreak(from: workouts.map(\.date))

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                statCell(value: "\(workouts.count)", label: "WORKOUTS")
                Rectangle().fill(Color.dsHairLine).frame(width: 1)
                statCell(value: "\(thisYearCount)", label: "THIS YEAR")
                Rectangle().fill(Color.dsHairLine).frame(width: 1)
                statCell(value: "\(streak)D", label: "STREAK")
            }
            .frame(height: 72)

            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.spaceMono(22, weight: .bold))
                .foregroundStyle(Color.inkPrimary)
            Text(label)
                .font(.spaceMono(8))
                .tracking(1.5)
                .foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Details

    private func detailsSection(user: User) -> some View {
        VStack(spacing: 0) {
            sectionLabel("DETAILS")

            detailRow(label: "EXPERIENCE", value: user.experienceLevel.displayName)
            detailRow(label: "UNITS", value: user.unitPreference.displayName)
            detailRow(label: "GENDER", value: user.gender.displayName)

            if user.weight > 0 {
                let weightVal = user.unitPreference == .lbs
                    ? "\(Int(user.weight * 2.20462)) LBS"
                    : "\(Int(user.weight)) KG"
                detailRow(label: "BODY WEIGHT", value: weightVal)
            }

            sectionLabel("ACCOUNT")
            detailRow(label: "MEMBER SINCE", value: memberSince(user: user))
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.spaceMono(9))
            .tracking(1.5)
            .foregroundStyle(Color.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 6)
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.spaceMono(9))
                    .tracking(1)
                    .foregroundStyle(Color.inkMuted)
                Spacer()
                Text(value)
                    .font(.archivo(14, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            Rectangle().fill(Color.dsHairLine).frame(height: 1)
        }
        .background(Color.canvasBg)
    }

    private func memberSince(user: User) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: user.createdAt ?? Date()).uppercased()
    }
}
