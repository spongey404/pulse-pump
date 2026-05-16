import SwiftUI
import FirebaseAuth

// MARK: - Helpers

private func feedMuscleIntensities(from names: [String]) -> [MuscleGroup: Double] {
    var result: [MuscleGroup: Double] = [:]
    for name in names {
        if let muscle = MuscleGroup.allCases.first(where: { $0.displayName == name }) {
            result[muscle] = 1.0
        }
    }
    return result
}

// MARK: - Activity Feed View

struct ActivityFeedView: View {
    @Bindable var viewModel: SocialViewModel
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SOCIAL")
                    .font(.display(28))
                    .tracking(0.5)
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                HStack(spacing: 14) {
                    Button {
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.mono(18))
                            .foregroundStyle(Color.inkMuted)
                    }
                    Button {
                    } label: {
                        Image(systemName: "person.2")
                            .font(.mono(18))
                            .foregroundStyle(Color.inkMuted)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.dsHairLine).frame(height: 0.5)
            }

            // Tab bar
            HStack(spacing: 0) {
                ForEach(["FRIENDS", "CHALLENGES"].indices, id: \.self) { i in
                    let label = ["FRIENDS", "CHALLENGES"][i]
                    let isActive = selectedTab == i
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = i
                        }
                    } label: {
                        Text(label)
                            .font(Font.mono(10, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(isActive ? Color.inkPrimary : Color.inkMuted)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(isActive ? Color.pumpAccent : Color.clear)
                                    .frame(height: 2)
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.dsHairLine).frame(height: 0.5)
            }

            // Feed content
            if selectedTab == 0 {
                feedContent
            } else {
                ChallengesView(viewModel: viewModel)
            }
        }
        .background(Color.canvasBg)
    }

    @ViewBuilder
    private var feedContent: some View {
        ScrollView {
            if viewModel.isLoadingFeed {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else if viewModel.feedItems.isEmpty {
                emptyFeedView
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.feedItems.enumerated()), id: \.element.id) { index, item in
                        FeedPostCard(
                            item: item,
                            currentUid: viewModel.currentUid ?? "",
                            onLike: { Task { await viewModel.toggleLike(postId: item.id) } }
                        )
                        if index < viewModel.feedItems.count - 1 {
                            Rectangle()
                                .fill(Color(uiColor: UIColor.systemBackground).opacity(0))
                                .frame(height: 8)
                                .background(Color.canvasBg.opacity(0.6))
                        }
                    }
                }
            }
        }
        .background(Color.canvasBg)
        .refreshable {
            await viewModel.loadFeed(forceRefresh: true)
        }
        .task {
            await viewModel.loadFeed()
        }
    }

    private var emptyFeedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.mono(42, weight: .light))
                .foregroundStyle(Color.inkFaint)

            VStack(spacing: 6) {
                Text("No friends yet")
                    .font(.mono(16, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                Text("Add friends by username to see\ntheir workouts here.")
                    .font(.mono(13))
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button {
            } label: {
                Text("FIND FRIENDS")
                    .font(.display(18))
                    .tracking(1.5)
                    .foregroundStyle(.white)
                    .frame(height: 44)
                    .padding(.horizontal, 24)
                    .background(Color.pumpAccent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 40)
    }
}

// MARK: - Feed Post Card

struct FeedPostCard: View {
    let item: WorkoutFeedItem
    let currentUid: String
    let onLike: () -> Void

    @State private var showDetail = false
    @State private var showComments = false
    @State private var menuOpen = false
    @State private var carouselSlide = 0
    @State private var showEmojiPicker = false

    private static let reactionEmojis = ["❤️", "💪", "🔥", "👊", "🏆", "😤"]
    private var isLiked: Bool { item.likes.contains(currentUid) }

    // Slides: "map" always present, "exercises" if any
    private var slides: [String] {
        var s: [String] = ["map"]
        if !item.exercises.isEmpty { s.append("exercises") }
        return s
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            cardHeader

            // Carousel
            carouselArea

            // Dot indicators
            if slides.count > 1 {
                HStack(spacing: 5) {
                    ForEach(slides.indices, id: \.self) { i in
                        Circle()
                            .fill(i == carouselSlide ? Color.pumpAccent : Color.inkFaint)
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.vertical, 6)
                .background(Color.tickerBgDark)
            }

            // Stats strip
            statsStrip

            // Caption
            if !item.caption.isEmpty {
                captionSection
            }

            // React / like row
            reactRow

            // Exercise list
            if !item.exercises.isEmpty {
                exerciseList
            }
        }
        .background(Color.surf)
        .sheet(isPresented: $showDetail) {
            FeedWorkoutDetailView(item: item)
        }
        .sheet(isPresented: $showComments) {
            CommentsView(postId: item.id)
        }
    }

    // MARK: - Header

    private var cardHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.surf2)
                    .overlay(Circle().strokeBorder(Color.dsHairLine.opacity(1.6), lineWidth: 1))
                Text(String(item.username.prefix(1)).uppercased())
                    .font(.display(15))
                    .foregroundStyle(Color.inkMuted)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 0) {
                    Text(item.username)
                        .font(.mono(14, weight: .medium))
                        .foregroundStyle(Color.inkPrimary)
                    Text("  @\(item.userId.prefix(8).lowercased())")
                        .font(Font.mono(9))
                        .foregroundStyle(Color.inkMuted)
                }
                Text("\(item.templateName ?? "Workout") · \(item.durationSeconds / 60)m · \(item.date, style: .relative)")
                    .font(Font.mono(9))
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(1)
            }

            Spacer()

            // ··· menu
            Button {
                menuOpen.toggle()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.mono(15))
                    .foregroundStyle(Color.inkMuted)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(PressScaleButtonStyle())
            .confirmationDialog("Post options", isPresented: $menuOpen) {
                Button("Steal program") {}
                Button("Save workout") {}
                Button("Send to friend") {}
                Button("Report post", role: .destructive) {}
                Button("Unfollow", role: .destructive) {}
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Carousel

    @ViewBuilder
    private var carouselArea: some View {
        ZStack(alignment: .topTrailing) {
            if slides[carouselSlide] == "map" {
                bodyMapSlide
            } else {
                exerciseSummarySlide
            }

            // Slide counter
            if slides.count > 1 {
                Text("\(carouselSlide + 1)/\(slides.count)")
                    .font(Font.mono(8))
                    .tracking(0.8)
                    .foregroundStyle(Color.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.45).blendMode(.normal))
                    .clipShape(Capsule())
                    .padding(8)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let threshold: CGFloat = 40
                    if value.translation.width < -threshold && carouselSlide < slides.count - 1 {
                        withAnimation(.easeInOut(duration: 0.2)) { carouselSlide += 1 }
                    } else if value.translation.width > threshold && carouselSlide > 0 {
                        withAnimation(.easeInOut(duration: 0.2)) { carouselSlide -= 1 }
                    }
                }
        )
        .onTapGesture {
            showDetail = true
        }
    }

    private var bodyMapSlide: some View {
        ZStack(alignment: .topTrailing) {
            Color.tickerBgDark
                .frame(maxWidth: .infinity)

            // Body3D
            Body3DSceneView(
                muscleIntensities: feedMuscleIntensities(from: item.musclesWorked),
                colorScheme: .mono,
                onMuscleTap: { _ in }
            )
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)

            // Badges (top-right)
            VStack(alignment: .trailing, spacing: 6) {
                // Improved badge
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                        Text("\(item.improvedCount)")
                            .font(.display(26))
                            .foregroundStyle(Color.signalUp)
                        Text("/\(item.totalExercises)")
                            .font(.display(13))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    Text("IMPROVED")
                        .font(Font.mono(7))
                        .tracking(0.8)
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.5).blendMode(.normal))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )

                // PR badge
                if item.prCount > 0 {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("★ \(item.prCount)")
                            .font(.display(22))
                            .foregroundStyle(Color.prGold)
                        Text("PR\(item.prCount > 1 ? "S" : "")")
                            .font(Font.mono(7))
                            .tracking(0.8)
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5).blendMode(.normal))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.prGold.opacity(0.53), lineWidth: 1)
                    )
                }
            }
            .padding(12)
        }
        .frame(height: 300)
        .clipped()
    }

    private var exerciseSummarySlide: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("WORKOUT SUMMARY — TAP FOR FULL DETAIL")
                .font(Font.mono(8, weight: .medium))
                .tracking(2.0)
                .foregroundStyle(Color.pumpAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            ForEach(item.exercises) { exercise in
                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(exercise.name)
                                .font(.mono(13))
                                .foregroundStyle(Color.white.opacity(0.95))
                        }
                        Text("\(exercise.sets.count) sets")
                            .font(Font.mono(9))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                    Spacer()
                    Text("—")
                        .font(Font.mono(10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.25))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.dsHairLine).frame(height: 0.5)
                }
            }
        }
        .frame(minHeight: 240, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.tickerBgDark)
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        HStack(spacing: 0) {
            statCell(label: "SETS", value: "\(item.exerciseCount * 3)")
            Rectangle().fill(Color.dsHairLine).frame(width: 0.5)
            statCell(label: "KCAL", value: "\(item.caloriesBurned)")
            Rectangle().fill(Color.dsHairLine).frame(width: 0.5)
            statCell(label: "DURATION", value: "\(item.durationSeconds / 60)m")
        }
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 0.5) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 0.5) }
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(Font.mono(8, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(Color.inkMuted)
            Text(value)
                .font(.display(20))
                .foregroundStyle(Color.inkPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Caption

    private var captionSection: some View {
        Text(item.caption)
            .font(.archivo(14))
            .foregroundStyle(Color.inkPrimary)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.dsHairLine).frame(height: 0.5)
            }
    }

    // MARK: - React Row

    private var reactRow: some View {
        VStack(spacing: 0) {
            // Emoji picker strip — appears inline above the buttons when long-pressed
            if showEmojiPicker {
                HStack(spacing: 0) {
                    ForEach(Self.reactionEmojis, id: \.self) { emoji in
                        Button {
                            withAnimation(.spring(response: 0.2)) { showEmojiPicker = false }
                            onLike()
                        } label: {
                            Text(emoji)
                                .font(.mono(24))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        withAnimation(.spring(response: 0.2)) { showEmojiPicker = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.mono(11, weight: .medium))
                            .foregroundStyle(Color.inkMuted)
                            .frame(width: 36, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .background(Color.surf)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.dsHairLine).frame(height: 0.5)
                }
            }

            HStack(spacing: 8) {
                // Like button — tap = like, long-press = reveal emoji picker
                Button(action: onLike) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.mono(14))
                            .foregroundStyle(isLiked ? Color.pumpAccent : Color.inkMuted)
                            .scaleEffect(isLiked ? 1.15 : 1)
                            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: isLiked)
                        Text("\(item.likes.count)")
                            .font(Font.mono(12, weight: .bold))
                            .foregroundStyle(isLiked ? Color.pumpAccent : Color.inkMuted)
                            .contentTransition(.numericText())
                        Text("HOLD")
                            .font(Font.mono(8))
                            .tracking(0.5)
                            .foregroundStyle(Color.inkFaint)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(isLiked ? Color.pumpAccent.opacity(0.08) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isLiked ? Color.pumpAccent.opacity(0.5) : Color.dsHairLine.opacity(1.6), lineWidth: 1)
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLiked)
                }
                .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.93))
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.4)
                        .onEnded { _ in withAnimation(.spring(response: 0.25)) { showEmojiPicker = true } }
                )

                Button { showComments = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                            .font(.mono(14))
                            .foregroundStyle(Color.inkMuted)
                        Text("\(item.commentCount)")
                            .font(Font.mono(12, weight: .bold))
                            .foregroundStyle(Color.inkMuted)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.dsHairLine.opacity(1.6), lineWidth: 1)
                    )
                }
                .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.93))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.dsHairLine).frame(height: 0.5)
            }
        }
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        VStack(spacing: 0) {
            Text("EXERCISES — TAP TO INSPECT")
                .font(Font.mono(9))
                .tracking(1.3)
                .foregroundStyle(Color.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            ForEach(item.exercises) { exercise in
                Button {
                    showDetail = true
                } label: {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(exercise.name)
                                    .font(.mono(14))
                                    .foregroundStyle(Color.inkPrimary)
                            }
                            Text("\(exercise.sets.count) sets")
                                .font(Font.mono(9))
                                .foregroundStyle(Color.inkMuted)
                        }
                        Spacer()
                        Text("—")
                            .font(Font.mono(10, weight: .bold))
                            .foregroundStyle(Color.inkFaint)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.dsHairLine).frame(height: 0.5)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Feed Workout Detail

struct FeedWorkoutDetailView: View {
    let item: WorkoutFeedItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Body map hero
                    if !item.musclesWorked.isEmpty {
                        Body3DSceneView(
                            muscleIntensities: feedMuscleIntensities(from: item.musclesWorked),
                            colorScheme: .mono,
                            onMuscleTap: { _ in }
                        )
                        .frame(height: 320)
                        .background(Color.tickerBgDark)
                    }

                    // Stats grid
                    HStack(spacing: 0) {
                        detailStatCell(value: "\(item.durationSeconds / 60)m", label: "DURATION")
                        Rectangle().fill(Color.dsHairLine).frame(width: 0.5)
                        detailStatCell(value: "\(item.exerciseCount)", label: "EXERCISES")
                        Rectangle().fill(Color.dsHairLine).frame(width: 0.5)
                        detailStatCell(value: "\(item.caloriesBurned)", label: "KCAL")
                        Rectangle().fill(Color.dsHairLine).frame(width: 0.5)
                        detailStatCell(value: "\(item.prCount)", label: "PRs")
                    }
                    .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 0.5) }
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 0.5) }

                    VStack(spacing: 12) {
                        if !item.caption.isEmpty {
                            Text(item.caption)
                                .font(.mono(14))
                                .foregroundStyle(Color.inkPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                        }

                        // Exercise breakdown
                        if !item.exercises.isEmpty {
                            VStack(spacing: 0) {
                                HStack {
                                    Text("EXERCISES")
                                        .font(Font.mono(9))
                                        .tracking(1.5)
                                        .foregroundStyle(Color.inkMuted)
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                Rectangle().fill(Color.dsHairLine).frame(height: 0.5)

                                ForEach(Array(item.exercises.enumerated()), id: \.element.id) { i, exercise in
                                    ExerciseBreakdownRow(exercise: exercise)
                                    if i < item.exercises.count - 1 {
                                        Rectangle()
                                            .fill(Color.dsHairLine)
                                            .frame(height: 0.5)
                                            .padding(.leading, 14)
                                    }
                                }
                            }
                            .background(Color.surf)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.dsHairLine, lineWidth: 0.5)
                            )
                            .padding(.horizontal, 16)
                        }

                        // Muscles worked
                        if !item.musclesWorked.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("MUSCLES WORKED")
                                    .font(Font.mono(9))
                                    .tracking(1.5)
                                    .foregroundStyle(Color.inkMuted)
                                FlowLayout(spacing: 4) {
                                    ForEach(item.musclesWorked.sorted(), id: \.self) { muscle in
                                        Text(muscle.uppercased())
                                            .font(Font.mono(9))
                                            .foregroundStyle(Color.pumpAccent)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.pumpSoft)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        }

                        Color.clear.frame(height: 32)
                    }
                }
            }
            .background(Color.canvasBg)
            .navigationTitle(item.templateName ?? "\(item.username)'s Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func detailStatCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.display(24)).foregroundStyle(Color.inkPrimary)
            Text(label).font(Font.mono(8)).tracking(0.5).foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.surf)
    }
}

// MARK: - Exercise Breakdown Row

struct ExerciseBreakdownRow: View {
    let exercise: FeedExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name.uppercased())
                .font(Font.mono(11, weight: .medium))
                .foregroundStyle(Color.inkPrimary)

            ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                HStack(spacing: 12) {
                    Text("S\(index + 1)")
                        .font(Font.mono(9))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 24, alignment: .leading)

                    if set.duration > 0 {
                        Text("\(set.duration)s")
                            .font(Font.mono(11, weight: .medium))
                            .foregroundStyle(Color.inkPrimary)
                    } else if set.distance > 0 {
                        Text(String(format: "%.0fm", set.distance))
                            .font(Font.mono(11, weight: .medium))
                            .foregroundStyle(Color.inkPrimary)
                    } else {
                        if set.weight > 0 {
                            Text(String(format: "%g kg", set.weight))
                                .font(Font.mono(11, weight: .medium))
                                .foregroundStyle(Color.inkPrimary)
                        }
                        if set.reps > 0 {
                            Text("× \(set.reps)")
                                .font(Font.mono(11))
                                .foregroundStyle(Color.inkMuted)
                        }
                    }
                    Spacer()
                    if set.setType != SetType.standard.rawValue {
                        Text(SetType(rawValue: set.setType)?.shortName ?? set.setType)
                            .font(Font.mono(9))
                            .foregroundStyle(Color.pumpAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.pumpSoft)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Legacy alias
typealias FeedItemView = FeedPostCard
