import SwiftUI
import SwiftData

// MARK: - More Tab  (matches Pump More Tab.html)

struct MoreTabView: View {
    @Bindable var tutorialViewModel: TutorialViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Query(filter: #Predicate<Workout> { !$0.isDraft }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    @State private var screen: MoreScreen = .hub
    @State private var showSignOutAlert = false

    private var user: User? { users.first }
    private var streak: Int { StreakCalculator.currentStreak(from: workouts.map(\.date)) }

    var body: some View {
        Group {
            switch screen {
            case .hub:      hubView
            case .history:  WorkoutHistoryView(onBack: { screen = .hub })
            case .profile:  ProfileView(onBack: { screen = .hub })
            case .settings: SettingsView(onBack: { screen = .hub })
            case .equipment: EquipmentProfilesView()
            case .pulsePlus: PulsePlusView(onBack: { screen = .hub })
            }
        }
        .animation(.easeInOut(duration: 0.22), value: screen)
    }

    // MARK: - Hub

    private var hubView: some View {
        VStack(spacing: 0) {
            // Page title
            VStack(spacing: 0) {
                Text("MORE")
                    .font(.archivo(28, weight: .black))
                    .tracking(0.5)
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                Rectangle().fill(Color.dsHairLine).frame(height: 1)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Profile card ───────────────────────────────
                    Button { screen = .profile } label: {
                        profileCard
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // ── Pulse+ banner ──────────────────────────────
                    Button { screen = .pulsePlus } label: {
                        plusBanner
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 4)

                    // ── TRAINING ───────────────────────────────────
                    sectionLabel("TRAINING")
                    moreRow(icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                            label: "History",
                            sub: "\(workouts.count) WORKOUTS · CALENDAR + LIST VIEW") { screen = .history }
                    moreRow(icon: "dumbbell",
                            label: "Equipment Profiles",
                            sub: "HOME GYM · COMMERCIAL GYM") { screen = .equipment }
                    moreRow(icon: "waveform.path.ecg",
                            label: "Weekly Recap",
                            sub: "AVAILABLE EVERY MONDAY") { }

                    // ── ACCOUNT ────────────────────────────────────
                    sectionLabel("ACCOUNT")
                    moreRow(icon: "person.crop.circle",
                            label: "Profile") { screen = .profile }
                    moreRow(icon: "gearshape",
                            label: "Settings") { screen = .settings }
                    moreRow(icon: "bolt.circle",
                            label: "Pulse+ Subscription",
                            sub: "FREE PLAN · UPGRADE",
                            accent: true) { screen = .pulsePlus }

                    // ── HELP ───────────────────────────────────────
                    sectionLabel("HELP")
                    moreRow(icon: "questionmark.circle",
                            label: "Tutorial",
                            sub: "REPLAY ONBOARDING WALKTHROUGH") { tutorialViewModel.start() }
                    moreRow(icon: "square.and.arrow.down",
                            label: "Data Import",
                            sub: "IMPORT FROM STRONG · HEVY") { }
                    moreRow(icon: "shield",
                            label: "Privacy & Legal") { }
                    moreRow(icon: "rectangle.portrait.and.arrow.right",
                            label: "Sign Out",
                            destructive: true,
                            chevron: false) { showSignOutAlert = true }

                    Spacer().frame(height: 32)
                }
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                // sign out handled via FirebaseAuthService
            }
        } message: {
            Text("You'll need to sign back in to access your data.")
        }
    }

    // MARK: - Profile card

    private var profileCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.surf2)
                    .frame(width: 52, height: 52)
                Text((user?.name.prefix(1) ?? "?").uppercased())
                    .font(.archivo(22, weight: .black))
                    .foregroundStyle(Color.inkMuted)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(user?.name ?? "Athlete")
                    .font(.archivo(16, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                Text("@\(user?.name.lowercased().replacingOccurrences(of: " ", with: "") ?? "athlete")")
                    .font(.spaceMono(9))
                    .tracking(0.8)
                    .foregroundStyle(Color.inkMuted)
                HStack(spacing: 0) {
                    Text("\(workouts.count)")
                        .font(.archivo(14, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    Text(" WORKOUTS")
                        .font(.spaceMono(8))
                        .tracking(0.5)
                        .foregroundStyle(Color.inkMuted)
                    Text("  \(streak)D")
                        .font(.archivo(14, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    Text(" STREAK")
                        .font(.spaceMono(8))
                        .tracking(0.5)
                        .foregroundStyle(Color.inkMuted)
                }
                .padding(.top, 2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.inkPrimary.opacity(0.2))
        }
        .padding(14)
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.dsHairLine, lineWidth: 1))
    }

    // MARK: - Pulse+ banner

    private var plusBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("UNLOCK PULSE+")
                    .font(.archivo(18, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                Text("SMART SUGGESTIONS · CLOUD SYNC · ANALYTICS")
                    .font(.spaceMono(9))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(14)
        .padding(.horizontal, 2)
        .background(Color.pumpAccent)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.pumpAccent.opacity(0.35), radius: 12, x: 0, y: 6)
    }

    // MARK: - Section label

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.spaceMono(9))
            .tracking(1.5)
            .foregroundStyle(Color.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }

    // MARK: - Nav row

    @ViewBuilder
    private func moreRow(
        icon: String,
        label: String,
        sub: String? = nil,
        badge: String? = nil,
        accent: Bool = false,
        destructive: Bool = false,
        chevron: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        let textColor: Color = destructive ? Color.signalDown : accent ? Color.pumpAccent : Color.inkPrimary
        let iconBg: Color = destructive ? Color.signalDown.opacity(0.10) : accent ? Color.pumpAccent.opacity(0.08) : Color.surf2

        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconBg)
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(textColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.archivo(14, weight: .medium))
                        .foregroundStyle(textColor)
                    if let sub {
                        Text(sub)
                            .font(.spaceMono(9))
                            .tracking(0.5)
                            .foregroundStyle(Color.inkMuted)
                    }
                }
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.spaceMono(9, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(Color.pumpAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.inkPrimary.opacity(0.2))
                }
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .background(Color.canvasBg)
        Divider().padding(.leading, 60)
    }
}

// MARK: - Screen enum

private enum MoreScreen {
    case hub, history, profile, settings, equipment, pulsePlus
}
