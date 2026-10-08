import SwiftUI
import SwiftData

enum SearchCategory: String, CaseIterable {
    case all       = "ALL"
    case exercises = "EXERCISES"
    case workouts  = "WORKOUTS"
    case friends   = "FRIENDS"
}

struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Exercise> { $0.deletedAt == nil }, sort: \Exercise.name) private var exercises: [Exercise]
    @Query(filter: #Predicate<Workout> { !$0.isDraft && $0.deletedAt == nil }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    @State private var searchText = ""
    @State private var activeCategory: SearchCategory = .all
    @State private var friendResults: [FirestoreUserProfile] = []
    @FocusState private var searchFocused: Bool
    private let firestoreService = FirestoreService()

    private var matchingExercises: [Exercise] {
        guard activeCategory == .all || activeCategory == .exercises else { return [] }
        guard !searchText.isEmpty else { return [] }
        return exercises.filter {
            ($0.isApproved || $0.isCustom) && $0.name.hasWordPrefix(searchText)
        }.prefix(8).map { $0 }
    }

    private var matchingWorkouts: [Workout] {
        guard activeCategory == .all || activeCategory == .workouts else { return [] }
        guard !searchText.isEmpty else { return [] }
        return workouts.filter {
            $0.template?.name.hasWordPrefix(searchText) == true ||
            $0.exerciseLogs.contains { $0.exercise?.name.hasWordPrefix(searchText) == true }
        }.prefix(5).map { $0 }
    }

    private var hasAnyResults: Bool {
        !matchingExercises.isEmpty || !matchingWorkouts.isEmpty ||
        (!friendResults.isEmpty && (activeCategory == .all || activeCategory == .friends))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Rectangle().fill(Color.dsHairLine).frame(height: 1)
                searchBar
                filterChips
                Rectangle().fill(Color.dsHairLine).frame(height: 1)

                if searchText.isEmpty {
                    emptyPrompt
                } else if !hasAnyResults {
                    noResults
                } else {
                    results
                }
            }
            .background(Color.canvasBg.ignoresSafeArea())
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    searchFocused = true
                }
            }
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: searchText) { _, newValue in
            guard !newValue.isEmpty,
                  activeCategory == .all || activeCategory == .friends else {
                if newValue.isEmpty { friendResults = [] }
                return
            }
            Task {
                friendResults = (try? await firestoreService.searchUsers(query: newValue)) ?? []
            }
        }
        .onChange(of: activeCategory) { _, cat in
            if cat == .friends || cat == .all, !searchText.isEmpty {
                Task {
                    friendResults = (try? await firestoreService.searchUsers(query: searchText)) ?? []
                }
            } else {
                friendResults = []
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.surf)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                    )
            }
            .buttonStyle(PressScaleButtonStyle())

            Text("GLOBAL SEARCH")
                .font(.archivo(26, weight: .black))
                .tracking(0.5)
                .foregroundStyle(Color.inkPrimary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.inkMuted)

            TextField("Search \(activeCategory == .all ? "everything" : activeCategory.rawValue.lowercased())...", text: $searchText)
                .font(.archivo(15))
                .foregroundStyle(Color.inkPrimary)
                .autocorrectionDisabled()
                .autocapitalization(.none)
                .submitLabel(.search)
                .focused($searchFocused)

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.inkMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.inkFaint, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchCategory.allCases, id: \.self) { cat in
                    filterChip(cat)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func filterChip(_ cat: SearchCategory) -> some View {
        let selected = activeCategory == cat
        return Button { activeCategory = cat } label: {
            Text(cat.rawValue)
                .font(.archivo(13, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? .white : Color.inkPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(selected ? Color.pumpAccent : Color.surf)
                )
                .overlay(
                    Capsule().strokeBorder(selected ? Color.clear : Color.inkFaint, lineWidth: 1)
                )
        }
        .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.95))
        .animation(.easeInOut(duration: 0.12), value: selected)
    }

    // MARK: - Empty Prompt

    private var emptyPrompt: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if activeCategory == .all || activeCategory == .exercises {
                    categoryHint(icon: "dumbbell",  label: "EXERCISES", desc: "Search 84+ exercises by name or muscle")
                }
                if activeCategory == .all || activeCategory == .workouts {
                    categoryHint(icon: "calendar",  label: "WORKOUTS",  desc: "Find past sessions by template name")
                }
                if activeCategory == .all || activeCategory == .friends {
                    categoryHint(icon: "person.2",  label: "FRIENDS",   desc: "Search users by name or username")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    private func categoryHint(icon: String, label: String, desc: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.pumpAccent.opacity(0.10))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accentInk)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.spaceMono(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.inkPrimary)
                Text(desc)
                    .font(.archivo(13))
                    .foregroundStyle(Color.inkMuted)
            }
        }
    }

    // MARK: - No Results

    private var noResults: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("NO RESULTS")
                .font(.archivo(28, weight: .black))
                .tracking(1)
                .foregroundStyle(Color.inkFaint)
            Text("Nothing matches \"\(searchText)\"")
                .font(.archivo(13))
                .foregroundStyle(Color.inkMuted)
            Spacer()
        }
    }

    // MARK: - Results

    private var results: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !matchingExercises.isEmpty {
                    sectionHeader("EXERCISES")
                    ForEach(Array(matchingExercises.enumerated()), id: \.element.id) { idx, exercise in
                        NavigationLink(value: exercise) {
                            exerciseRow(exercise)
                        }
                        .buttonStyle(.plain)
                        if idx < matchingExercises.count - 1 {
                            Rectangle().fill(Color.dsHairLine).frame(height: 1).padding(.leading, 70)
                        }
                    }
                    Rectangle().fill(Color.dsHairLine).frame(height: 1)
                }

                if !matchingWorkouts.isEmpty {
                    sectionHeader("WORKOUTS")
                    ForEach(Array(matchingWorkouts.enumerated()), id: \.element.id) { idx, workout in
                        workoutRow(workout)
                        if idx < matchingWorkouts.count - 1 {
                            Rectangle().fill(Color.dsHairLine).frame(height: 1).padding(.leading, 70)
                        }
                    }
                    Rectangle().fill(Color.dsHairLine).frame(height: 1)
                }

                let filteredFriends = (activeCategory == .all || activeCategory == .friends) ? friendResults : []
                if !filteredFriends.isEmpty {
                    sectionHeader("FRIENDS")
                    ForEach(Array(filteredFriends.enumerated()), id: \.element.uid) { idx, profile in
                        friendRow(profile)
                        if idx < filteredFriends.count - 1 {
                            Rectangle().fill(Color.dsHairLine).frame(height: 1).padding(.leading, 70)
                        }
                    }
                }

                Color.clear.frame(height: 40)
            }
        }
    }

    private func sectionHeader(_ label: String) -> some View {
        HStack {
            Text(label)
                .font(.spaceMono(9))
                .tracking(1.5)
                .foregroundStyle(Color.accentInk)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(Color.surf2)
        .overlay(Rectangle().fill(Color.dsHairLine).frame(height: 1), alignment: .bottom)
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.pumpAccent.opacity(0.10))
                    .frame(width: 40, height: 40)
                Image(systemName: exercise.movementPattern.sfSymbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accentInk)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.archivo(15, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                HStack(spacing: 4) {
                    Text(exercise.primaryMuscleGroups.map(\.displayName).joined(separator: ", "))
                        .font(.spaceMono(9)).foregroundStyle(Color.inkMuted)
                    Text("·").font(.spaceMono(9)).foregroundStyle(Color.inkFaint)
                    Text(exercise.equipmentType.displayName)
                        .font(.spaceMono(9)).foregroundStyle(Color.inkMuted)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.inkFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func workoutRow(_ workout: Workout) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.signalUp.opacity(0.10))
                    .frame(width: 40, height: 40)
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.signalUp)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text((workout.template?.name ?? "Workout").uppercased())
                    .font(.archivo(15, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                HStack(spacing: 4) {
                    Text(relativeDate(workout.date))
                        .font(.spaceMono(9)).foregroundStyle(Color.inkMuted)
                    Text("·").font(.spaceMono(9)).foregroundStyle(Color.inkFaint)
                    Text("\(workout.workingSetCount) SETS")
                        .font(.spaceMono(9)).foregroundStyle(Color.inkMuted)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func friendRow(_ profile: FirestoreUserProfile) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.surf2).frame(width: 40, height: 40)
                Text(String(profile.displayName.prefix(1)).uppercased())
                    .font(.archivo(16, weight: .black))
                    .foregroundStyle(Color.inkMuted)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(profile.displayName)
                    .font(.archivo(15, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                Text("@\(profile.username)")
                    .font(.spaceMono(9)).foregroundStyle(Color.inkMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.inkFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date()).uppercased()
    }
}
