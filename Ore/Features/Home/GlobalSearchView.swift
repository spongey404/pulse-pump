import SwiftUI
import SwiftData

enum SearchCategory: String, CaseIterable {
    case all       = "All"
    case exercises = "Exercises"
    case workouts  = "Workouts"
    case friends   = "Friends"
}

/// The pure rules behind the search screen (Global Search Final.dc.html), kept out of the view so they can be tested.
enum GlobalSearchRules {
    /// Rows a section shows: three while looking at everything (with SEE ALL ›), the full list under one filter.
    static func rowLimit(for category: SearchCategory) -> Int { category == .all ? 3 : 20 }

    /// Whether a section gets a SEE ALL › link.
    static func showsSeeAll(hits: Int, category: SearchCategory) -> Bool { hits > rowLimit(for: category) }

    /// "BENCH PRESS" header: label and match count.
    static func sectionTitle(_ label: String, hits: Int) -> String { "\(label.uppercased()) · \(hits)" }

    /// Empty-state rows per section: a taste while on All, the whole list under a filter.
    static func emptyLimit(top: Int, category: SearchCategory) -> Int { category == .all ? top : 6 }
}

/// Recent searches: newest first, no duplicates (ignoring case), capped.
struct SearchRecents: Equatable {
    static let cap = 8
    static let defaultsKey = "globalSearchRecents"
    private(set) var items: [String]

    init(_ items: [String] = []) { self.items = Array(items.prefix(Self.cap)) }

    mutating func add(_ term: String) {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        items.removeAll { $0.caseInsensitiveCompare(t) == .orderedSame }
        items.insert(t, at: 0)
        items = Array(items.prefix(Self.cap))
    }
    mutating func remove(_ term: String) { items.removeAll { $0 == term } }
    mutating func clear() { items = [] }

    static func load(_ defaults: UserDefaults = .standard) -> SearchRecents {
        SearchRecents(defaults.stringArray(forKey: defaultsKey) ?? [])
    }
    func save(_ defaults: UserDefaults = .standard) { defaults.set(items, forKey: Self.defaultsKey) }
}

struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var unit
    @Query(filter: #Predicate<Exercise> { $0.deletedAt == nil }, sort: \Exercise.name) private var exercises: [Exercise]
    @Query(filter: #Predicate<Workout> { !$0.isDraft && $0.deletedAt == nil }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    @State private var searchText = ""
    @State private var activeCategory: SearchCategory = .all
    @State private var recents = SearchRecents.load()
    @State private var social = SocialViewModel.shared
    @FocusState private var searchFocused: Bool

    // MARK: Matching

    /// Friends whose name or handle matches, plus an exact-handle hit (users can't be listed).
    private var friendResults: [FirestoreUserProfile] {
        guard !searchText.isEmpty, activeCategory == .all || activeCategory == .friends else { return [] }
        let local = social.friends.filter {
            $0.shownName.localizedCaseInsensitiveContains(searchText) || $0.username.localizedCaseInsensitiveContains(searchText)
        }
        let exact = social.searchResults.compactMap(\.profile)
        var seen = Set<String>()
        return (local + exact).filter { seen.insert($0.uid).inserted }
    }

    private var matchingExercises: [Exercise] {
        guard activeCategory == .all || activeCategory == .exercises, !searchText.isEmpty else { return [] }
        return exercises.filter { ($0.isApproved || $0.isCustom) && $0.name.hasWordPrefix(searchText) }
    }

    private var matchingWorkouts: [Workout] {
        guard activeCategory == .all || activeCategory == .workouts, !searchText.isEmpty else { return [] }
        return workouts.filter {
            $0.template?.name.hasWordPrefix(searchText) == true ||
            $0.exerciseLogs.contains { $0.exercise?.name.hasWordPrefix(searchText) == true }
        }
    }

    private var hasAnyResults: Bool {
        !matchingExercises.isEmpty || !matchingWorkouts.isEmpty || !friendResults.isEmpty
    }

    /// The exercises logged most over the last two months of sessions.
    private var topExercises: [Exercise] {
        var counts: [UUID: Int] = [:]
        for w in workouts.prefix(60) {
            for log in w.exerciseLogs { if let e = log.exercise { counts[e.id, default: 0] += log.sets.count } }
        }
        let byId = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        return counts.sorted { $0.value > $1.value }.compactMap { byId[$0.key] }
    }

    /// "100×5": the heaviest set of the last session that included the exercise.
    private func lastTopSet(of exercise: Exercise) -> String {
        for w in workouts {
            let sets = w.exerciseLogs.filter { $0.exercise?.id == exercise.id }.flatMap(\.sets).filter { $0.setType != .warmup }
            if let best = sets.max(by: { $0.weight < $1.weight }), best.weight > 0 {
                return "\(unit.number(best.weight))×\(best.reps)"
            }
        }
        return ""
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchRow
                filterPills
                content
            }
            .background(Color.canvasBg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { searchFocused = true }
            }
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
        }
        .ignoresSafeArea(.keyboard)
        .task(id: searchText) {
            guard !searchText.isEmpty, activeCategory == .all || activeCategory == .friends else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            if !social.graphLoaded { await social.loadGraph() }
            await social.searchUsers(query: searchText)
        }
    }

    @ViewBuilder private var content: some View {
        if searchText.isEmpty {
            emptyState
        } else if !hasAnyResults {
            noResults
        } else {
            results
        }
    }

    // MARK: Field row

    private var searchRow: some View {
        HStack(spacing: 6) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: 32, height: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.inkMuted)
                TextField("Search \(placeholderScope)", text: $searchText)
                    .font(.archivo(15))
                    .foregroundStyle(Color.inkPrimary)
                    .tint(Color.oreAccent)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .onSubmit { recents.add(searchText); recents.save() }
                    .accessibilityIdentifier(AX.exercise.search)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.canvasBg)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Color.inkPrimary.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.leading, 12).padding(.trailing, 10)
            .frame(height: 42)
            .background(Color.surf2)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.leading, 10).padding(.trailing, 16)
        .padding(.vertical, 4)
    }

    private var placeholderScope: String {
        activeCategory == .all ? "exercises, workouts, friends" : activeCategory.rawValue.lowercased()
    }

    // MARK: Pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchCategory.allCases, id: \.self) { pill($0) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8).padding(.bottom, 12)
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .padding(.top, 6)
    }

    private func pill(_ cat: SearchCategory) -> some View {
        let selected = activeCategory == cat
        return Button { activeCategory = cat } label: {
            Text(cat.rawValue)
                .font(.archivo(14, weight: .semibold))
                .foregroundStyle(selected ? Color.onAccent : Color.inkPrimary)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(Capsule().fill(selected ? Color.oreAccent : Color.surf2))
                .overlay(Capsule().strokeBorder(selected ? Color.oreAccent : Color.dsHairLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: selected)
        .accessibilityIdentifier(AX.exercise.searchPill(cat.rawValue))
    }

    // MARK: Empty state: recents, then what you use

    private var emptyState: some View {
        let top = topExercises
        let friends = social.friends
        return ScrollView {
            VStack(spacing: 0) {
                if activeCategory == .all, !recents.items.isEmpty {
                    sectionHeader("RECENT", action: "CLEAR") { recents.clear(); recents.save() }
                    ForEach(recents.items, id: \.self) { term in recentRow(term) }
                }
                if activeCategory == .all || activeCategory == .exercises {
                    let list = Array(top.prefix(GlobalSearchRules.emptyLimit(top: 3, category: activeCategory)))
                    if !list.isEmpty {
                        sectionHeader("YOUR TOP EXERCISES")
                        ForEach(list, id: \.id) { exerciseLink($0) }
                    }
                }
                if activeCategory == .workouts {
                    sectionHeader("RECENT WORKOUTS")
                    ForEach(Array(workouts.prefix(5)), id: \.id) { workoutRow($0) }
                }
                if activeCategory == .all || activeCategory == .friends {
                    let list = Array(friends.prefix(activeCategory == .all ? 2 : 4))
                    if !list.isEmpty {
                        sectionHeader("FRIENDS")
                        ForEach(list, id: \.uid) { friendRow($0) }
                    }
                }
                Color.clear.frame(height: 28)
            }
        }
    }

    private func recentRow(_ term: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 14)).foregroundStyle(Color.inkMuted)
            Text(term)
                .font(.archivo(15)).foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button { recents.remove(term); recents.save() } label: {
                Text("×").font(.archivo(15)).foregroundStyle(Color.inkMuted)
                    .frame(width: 28, height: 28).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, -6)
            .accessibilityLabel("Remove \(term)")
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .onTapGesture { searchText = term }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: No results

    private var noResults: some View {
        VStack(alignment: .leading) {
            Text("No matches for “\(searchText)”.")
                .font(.archivo(15)).foregroundStyle(Color.inkSecondary)
                .padding(.horizontal, 16).padding(.vertical, 28)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Results

    private var results: some View {
        let limit = GlobalSearchRules.rowLimit(for: activeCategory)
        let ex = matchingExercises, wo = matchingWorkouts, fr = friendResults
        return ScrollView {
            VStack(spacing: 0) {
                if !ex.isEmpty {
                    sectionHeader(GlobalSearchRules.sectionTitle("Exercises", hits: ex.count),
                                  action: GlobalSearchRules.showsSeeAll(hits: ex.count, category: activeCategory) ? "SEE ALL ›" : nil) { activeCategory = .exercises }
                    ForEach(Array(ex.prefix(limit)), id: \.id) { exerciseLink($0) }
                }
                if !wo.isEmpty {
                    sectionHeader(GlobalSearchRules.sectionTitle("Workouts", hits: wo.count),
                                  action: GlobalSearchRules.showsSeeAll(hits: wo.count, category: activeCategory) ? "SEE ALL ›" : nil) { activeCategory = .workouts }
                    ForEach(Array(wo.prefix(limit)), id: \.id) { workoutRow($0) }
                }
                if !fr.isEmpty {
                    sectionHeader(GlobalSearchRules.sectionTitle("Friends", hits: fr.count),
                                  action: GlobalSearchRules.showsSeeAll(hits: fr.count, category: activeCategory) ? "SEE ALL ›" : nil) { activeCategory = .friends }
                    ForEach(Array(fr.prefix(limit)), id: \.uid) { friendRow($0) }
                }
                Color.clear.frame(height: 28)
            }
        }
    }

    // MARK: Pieces

    private func sectionHeader(_ label: String, action: String? = nil, onAction: @escaping () -> Void = {}) -> some View {
        HStack {
            Text(label)
                .font(.spaceMono(9)).tracking(1.5).foregroundStyle(Color.inkMuted)
            Spacer()
            if let action {
                Button(action: onAction) {
                    Text(action).font(.spaceMono(9, weight: .bold)).tracking(1.2).foregroundStyle(Color.inkPrimary)
                        .frame(minHeight: 28).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    /// One result row: a title with a small caps line under it, and an optional value on the right.
    private func row(title: String, meta: String?, right: String = "", leading: AnyView? = nil) -> some View {
        HStack(spacing: 12) {
            if let leading { leading }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                if let meta, !meta.isEmpty {
                    Text(meta).font(.spaceMono(8)).tracking(1.2).foregroundStyle(Color.inkMuted).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if !right.isEmpty {
                Text(right).font(.spaceMono(11)).foregroundStyle(Color.inkSecondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func exerciseLink(_ exercise: Exercise) -> some View {
        NavigationLink(value: exercise) {
            row(title: exercise.name,
                meta: "\(exercise.equipmentType.displayName) · \(exercise.primaryMuscleGroups.first?.displayName ?? "")".uppercased(),
                right: lastTopSet(of: exercise))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            if !searchText.isEmpty { recents.add(searchText); recents.save() }
        })
        .accessibilityIdentifier(AX.exercise.searchRow(exercise.name))
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "EEE d MMM"; return f
    }()

    private func workoutRow(_ workout: Workout) -> some View {
        let name = workout.template?.name ?? "Workout"
        let date = Self.dayFormatter.string(from: workout.date).uppercased()
        let minutes = Int(workout.duration) / 60, seconds = Int(workout.duration) % 60
        return row(title: name,
                   meta: "\(date) · \(workout.exerciseLogs.count) EXERCISES",
                   right: workout.duration > 0 ? String(format: "%d:%02d", minutes, seconds) : "")
    }

    private func friendRow(_ profile: FirestoreUserProfile) -> some View {
        row(title: profile.shownName, meta: "@\(profile.username)".uppercased(),
            leading: AnyView(
                Text(String(profile.shownName.prefix(2)).uppercased())
                    .font(.spaceMono(10, weight: .bold)).foregroundStyle(Color.inkPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.surf2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            ))
    }
}
