import SwiftUI
import FirebaseAuth
import PhotosUI

struct WorkoutCompletionView: View {
    let data: WorkoutCompletionData
    let userName: String
    let onDismiss: () -> Void

    @State private var caption = ""
    @State private var shareDestination: ShareDestination = .feed
    @State private var showDotsMenu = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var thumbnailImage: Image?
    @State private var thumbnailUIImage: UIImage?
    @State private var avatarImage: Image?
    @State private var shareCardHeight: CGFloat = 560
    @State private var photoSlideHeight: CGFloat = 300
    @State private var carouselPage: Int? = 0

    enum ShareDestination { case feed, instagram, messages }

    private var shortDate: String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM yyyy"
        return f.string(from: Date()).uppercased()
    }
    private var shortDateBrief: String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"
        return f.string(from: Date()).uppercased()
    }

    private var tickerItems: [TickerItem] {
        var items: [TickerItem] = [
            TickerItem(label: (data.workoutName ?? "WORKOUT").uppercased(), value: "DONE", direction: nil),
        ]
        if data.prCount > 0 {
            items.append(TickerItem(label: "\(data.prCount) NEW PR\(data.prCount == 1 ? "" : "S")", value: "★", direction: .up))
        }
        items.append(TickerItem(label: "IMPROVED",  value: "\(data.improvedCount)/\(data.totalExercises)", direction: .up))
        items.append(TickerItem(label: "SETS",      value: "\(data.totalSets)",           direction: nil))
        items.append(TickerItem(label: "KCAL",      value: "\(Int(data.calories))",       direction: nil))
        items.append(TickerItem(label: "DURATION",  value: data.formattedDuration,        direction: nil))
        return items + items
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                headerBar
                ScrollView {
                    VStack(spacing: 0) {
                        if let photo = thumbnailImage {
                            GeometryReader { proxy in
                                let w = proxy.size.width
                                ScrollView(.horizontal) {
                                    HStack(alignment: .top, spacing: 0) {
                                        // Photo slide — natural aspect-ratio height
                                        photo
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: w)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            .overlay(alignment: .topTrailing) {
                                                Button {
                                                    thumbnailImage = nil
                                                    thumbnailUIImage = nil
                                                    selectedPhotoItem = nil
                                                    carouselPage = nil
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 20))
                                                        .foregroundStyle(.white)
                                                        .shadow(radius: 4)
                                                        .padding(10)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .background(GeometryReader { g in
                                                Color.clear.onAppear { photoSlideHeight = g.size.height }
                                            })
                                            .id(0)

                                        // Share card slide — natural content height
                                        shareCard
                                            .frame(width: w)
                                            .background(GeometryReader { g in
                                                Color.clear.onAppear { shareCardHeight = g.size.height }
                                            })
                                            .id(1)
                                    }
                                    .scrollTargetLayout()
                                }
                                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                                .scrollBounceBehavior(.basedOnSize)
                                .scrollIndicators(.hidden)
                                .scrollPosition(id: $carouselPage)
                            }
                            .frame(height: (carouselPage ?? 0) == 0 ? photoSlideHeight : shareCardHeight)
                            .animation(.spring(response: 0.18, dampingFraction: 0.95), value: carouselPage)
                            .padding(.horizontal, 14)
                            .padding(.top, 14)

                            // Page dots — outside the animated frame so they don't jump
                            HStack(spacing: 6) {
                                ForEach(0..<2, id: \.self) { i in
                                    Circle()
                                        .fill((carouselPage ?? 0) == i ? Color.inkPrimary : Color.inkMuted.opacity(0.4))
                                        .frame(width: 6, height: 6)
                                        .animation(.easeInOut(duration: 0.12), value: carouselPage)
                                }
                            }
                            .padding(.top, 8)
                        } else {
                            shareCard
                                .background(GeometryReader { geo in
                                    Color.clear.onAppear { shareCardHeight = geo.size.height }
                                })
                                .padding(.horizontal, 14)
                                .padding(.top, 14)
                        }
                        captionComposer
                        Color.clear.frame(height: 24)
                    }
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.horizontal)
                }
            }

            if showDotsMenu {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { showDotsMenu = false }
                    }
                    .transition(.opacity)
                dotsMenu
                    .padding(.horizontal, 14)
                    .padding(.bottom, 86)
                    .transition(.scale(scale: 0.88, anchor: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .task { await loadAvatar() }
        .onChange(of: selectedPhotoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    thumbnailUIImage = uiImage
                    thumbnailImage = Image(uiImage: uiImage)
                    let availableWidth = UIScreen.main.bounds.width - 28
                    let ratio = uiImage.size.height / uiImage.size.width
                    photoSlideHeight = availableWidth * ratio
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.95)) {
                        carouselPage = 0
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                ShareSheet(items: [img]).presentationDetents([.medium, .large])
            }
        }
    }

    private func loadAvatar() async {
        guard let url = Auth.auth().currentUser?.photoURL else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let uiImage = UIImage(data: data) else { return }
        avatarImage = Image(uiImage: uiImage)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            HStack(spacing: 8) {
                Button(action: onDismiss) {
                    Text("‹")
                        .font(.mono(24, weight: .light))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 28, height: 32)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 1) {
                    Text("WORKOUT COMPLETE")
                        .font(Font.spaceMono(9, weight: .bold))
                        .foregroundStyle(Color.pumpAccent)
                        .tracking(1.2)
                    Text((data.workoutName ?? "WORKOUT").uppercased())
                        .font(.display(18))
                        .foregroundStyle(Color.inkPrimary)
                        .tracking(0.8)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(shortDateBrief)
                .font(Font.spaceMono(10))
                .foregroundStyle(Color.inkMuted)
                .tracking(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.canvasBg)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: - Share Card

    private var shareCard: some View {
        VStack(spacing: 0) {
            TickerStripView(items: tickerItems)
            VStack(spacing: 0) {
                // Name + duration
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shortDate)
                            .font(Font.spaceMono(9))
                            .foregroundStyle(Color.inkMuted)
                            .tracking(1.6)
                        Text((data.workoutName ?? "WORKOUT").uppercased())
                            .font(.display(44))
                            .foregroundStyle(Color.inkPrimary)
                            .tracking(0.5)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("DURATION")
                            .font(Font.spaceMono(8))
                            .foregroundStyle(Color.inkMuted)
                            .tracking(1.2)
                        Text(data.formattedDuration)
                            .font(.display(26))
                            .foregroundStyle(Color.inkPrimary)
                            .tracking(1)
                    }
                    .padding(.top, 4)
                }
                .padding(.bottom, 12)

                statsRow.padding(.bottom, 12)
                bodyHeroRow.padding(.bottom, 12)
                exerciseTable

                // Watermark
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.pumpAccent).frame(width: 7, height: 7)
                    Text("PULSE/PUMP")
                        .font(Font.spaceMono(8))
                        .foregroundStyle(Color.inkMuted)
                        .tracking(1.5)
                    Spacer()
                }
                .padding(.top, 10)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.dsHairLine, lineWidth: 1))
    }

    // MARK: Photo Thumbnail

    private var photoThumbnailSection: some View {
        Group {
            if let img = thumbnailImage {
                ZStack(alignment: .topTrailing) {
                    img
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipped()
                    Button {
                        thumbnailImage = nil
                        thumbnailUIImage = nil
                        selectedPhotoItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 12)
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 14, weight: .medium))
                        Text("ADD PHOTO")
                            .font(Font.spaceMono(9, weight: .bold))
                            .tracking(1.2)
                    }
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(Color.dsHairLine)
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    thumbnailUIImage = uiImage
                    thumbnailImage = Image(uiImage: uiImage)
                    let availableWidth = UIScreen.main.bounds.width - 28
                    let ratio = uiImage.size.height / uiImage.size.width
                    photoSlideHeight = availableWidth * ratio
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.95)) {
                        carouselPage = 0
                    }
                }
            }
        }
    }

    // MARK: Stats Row

    private var volString: String {
        let t = data.exercises.flatMap(\.sets).reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        return t >= 1000 ? String(format: "%.1fK", t / 1000) : "\(Int(t))"
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(label: "SETS",   value: "\(data.totalSets)",      isLast: false)
            statCell(label: "KCAL",   value: "\(Int(data.calories))",  isLast: false)
            statCell(label: "VOL",    value: volString,                 isLast: false)
            statCell(label: "STREAK", value: "\(data.streakCount)",     isLast: true)
        }
        .overlay(alignment: .top)    { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func statCell(label: String, value: String, isLast: Bool) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(Font.spaceMono(8))
                .foregroundStyle(Color.inkMuted)
                .tracking(1.2)
            Text(value)
                .font(.display(21))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .overlay(alignment: .trailing) {
            if !isLast { Rectangle().fill(Color.dsHairLine).frame(width: 1) }
        }
    }

    // MARK: Body + Hero Row

    private var bodyHeroRow: some View {
        HStack(alignment: .center, spacing: 14) {
            HStack(spacing: 5) {
                VStack(spacing: 3) {
                    Text("FRONT")
                        .font(Font.spaceMono(7))
                        .foregroundStyle(Color.inkMuted)
                        .tracking(1)
                    ThermalBodyCanvas(muscles: data.musclesWorked, showBack: false)
                        .frame(width: 60, height: 144)
                }
                VStack(spacing: 3) {
                    Text("BACK")
                        .font(Font.spaceMono(7))
                        .foregroundStyle(Color.inkMuted)
                        .tracking(1)
                    ThermalBodyCanvas(muscles: data.musclesWorked, showBack: true)
                        .frame(width: 60, height: 144)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom, spacing: 5) {
                    Text("\(data.improvedCount)")
                        .font(.display(58))
                        .foregroundStyle(Color.signalUp)
                        .lineLimit(1)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("OF \(data.totalExercises)")
                            .font(Font.spaceMono(9))
                            .foregroundStyle(Color.inkMuted)
                            .tracking(0.8)
                        Text("IMPROVED")
                            .font(Font.spaceMono(8))
                            .foregroundStyle(Color.inkMuted)
                            .tracking(0.8)
                    }
                    .padding(.bottom, 5)
                }

                if data.prCount > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("★ \(data.prCount) NEW PR\(data.prCount == 1 ? "" : "S")")
                            .font(.display(18))
                            .foregroundStyle(Color.prGold)
                            .tracking(0.5)
                            .padding(.top, 7)
                            .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                        ForEach(data.prDetails, id: \.exerciseName) { pr in
                            HStack(spacing: 5) {
                                Text(pr.exerciseName.uppercased())
                                    .font(Font.spaceMono(9))
                                    .foregroundStyle(Color.inkMuted)
                                    .lineLimit(1)
                                Text(pr.isWeightPR
                                     ? "+\(String(format: "%g", pr.weightDelta))KG"
                                     : "+\(pr.repsDelta) REP\(pr.repsDelta == 1 ? "" : "S")")
                                    .font(Font.spaceMono(9, weight: .bold))
                                    .foregroundStyle(Color.prGold)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Exercise Table

    private var exerciseTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("EXERCISE").frame(maxWidth: .infinity, alignment: .leading)
                Text("SETS").frame(width: 36, alignment: .center)
                Text("BEST SET").frame(width: 66, alignment: .trailing)
                Text("▲").frame(width: 28, alignment: .trailing)
            }
            .font(Font.spaceMono(7))
            .foregroundStyle(Color.inkMuted)
            .tracking(1.2)
            .padding(.vertical, 5)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

            let sorted = data.exercises.sorted { $0.improvementScore > $1.improvementScore }
            let rows = Array(sorted.prefix(7).enumerated())
            let prExerciseNames = Set(data.prDetails.map { $0.exerciseName })
            ForEach(rows, id: \.element.id) { i, ex in
                let improved = ex.improvementScore > 0
                let isPR = prExerciseNames.contains(ex.name)
                HStack(spacing: 0) {
                    HStack(spacing: 3) {
                        Text(ex.name)
                            .font(.archivo(12, weight: improved ? .bold : .regular))
                            .foregroundStyle(Color.inkPrimary)
                            .lineLimit(1)
                        if isPR {
                            Text("★")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.prGold)
                                .offset(y: -1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(ex.sets.count)")
                        .font(Font.spaceMono(10))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 36, alignment: .center)
                    Text(bestSetText(ex))
                        .font(.display(13))
                        .foregroundStyle(Color.inkPrimary)
                        .tracking(0.5)
                        .frame(width: 66, alignment: .trailing)
                    Text(improved ? "+\(String(format: "%.0f", ex.improvementScore))%" : "—")
                        .font(Font.spaceMono(10))
                        .foregroundStyle(improved ? Color.signalUp : Color.inkMuted)
                        .frame(width: 28, alignment: .trailing)
                }
                .padding(.vertical, 4)
                .overlay(alignment: .bottom) {
                    if i < rows.count - 1 { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
                }
            }

            if data.exercises.count > 7 {
                Text("+\(data.exercises.count - 7) MORE")
                    .font(Font.spaceMono(9))
                    .foregroundStyle(Color.inkMuted)
                    .tracking(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 5)
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func bestSetText(_ ex: FeedExercise) -> String {
        guard let best = ex.sets.max(by: { $0.weight * Double($0.reps) < $1.weight * Double($1.reps) }) else { return "—" }
        return best.weight > 0 ? "\(String(format: "%g", best.weight))×\(best.reps)" : "\(best.reps)r"
    }

    // MARK: - Caption Composer

    private var captionComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Add / change photo
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: thumbnailImage == nil ? "photo.badge.plus" : "photo.fill")
                        .font(.system(size: 13, weight: .medium))
                    Text(thumbnailImage == nil ? "ADD PHOTO" : "CHANGE PHOTO")
                        .font(Font.spaceMono(9, weight: .bold))
                        .tracking(0.8)
                }
                .foregroundStyle(thumbnailImage == nil ? Color.inkMuted : Color.pumpAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Color.surf)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(
                    thumbnailImage == nil ? Color.dsHairLine : Color.pumpAccent.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Avatar + text input
            HStack(alignment: .top, spacing: 10) {
                Group {
                    if let img = avatarImage {
                        img.resizable().scaledToFill()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.dsHairLine, lineWidth: 1))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.surf2)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.dsHairLine, lineWidth: 1))
                            .frame(width: 34, height: 34)
                            .overlay {
                                Text(avatarInitial)
                                    .font(.archivo(15, weight: .black))
                                    .foregroundStyle(Color.inkPrimary)
                            }
                    }
                }
                .frame(width: 34, height: 34)
                ZStack(alignment: .topLeading) {
                    if caption.isEmpty {
                        Text("Add a caption…")
                            .font(.archivo(14))
                            .foregroundStyle(Color.inkMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }
                    TextEditor(text: $caption)
                        .font(.archivo(14))
                        .foregroundStyle(Color.inkPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(minHeight: 56)
                }
                .background(Color.surf)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.dsHairLine, lineWidth: 1))
            }

            // Tag friends
            VStack(alignment: .leading, spacing: 7) {
                Text("TAG FRIENDS")
                    .font(Font.spaceMono(9))
                    .foregroundStyle(Color.inkMuted)
                    .tracking(1.3)
                HStack(spacing: 6) {
                    Button { } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .medium))
                            Text("ADD")
                                .font(Font.spaceMono(9))
                                .tracking(0.5)
                        }
                        .foregroundStyle(Color.inkMuted)
                        .frame(height: 30)
                        .padding(.horizontal, 10)
                        .overlay(
                            Capsule()
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3]))
                                .foregroundStyle(Color.inkFaint)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Share to
            VStack(alignment: .leading, spacing: 7) {
                Text("SHARE TO")
                    .font(Font.spaceMono(9))
                    .foregroundStyle(Color.inkMuted)
                    .tracking(1.3)
                HStack(spacing: 6) {
                    shareChip("PULSE FEED",  active: shareDestination == .feed)      { shareDestination = .feed }
                    shareChip("INSTAGRAM",   active: shareDestination == .instagram) { shareDestination = .instagram }
                    shareChip("MESSAGES",    active: shareDestination == .messages)  { shareDestination = .messages }
                }
            }

            // POST + ···
            HStack(spacing: 8) {
                Button(action: postAndDismiss) {
                    Text("POST")
                        .font(.display(22))
                        .foregroundStyle(.white)
                        .tracking(1.5)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.pumpAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(PressScaleButtonStyle(scaleAmount: 0.97))

                Button { withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) { showDotsMenu.toggle() } } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(width: 54, height: 54)
                        .background(Color.surf)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.dsHairLine, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.canvasBg)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    // MARK: - Dots Menu

    private var dotsMenu: some View {
        VStack(spacing: 0) {
            dotsRow(icon: "square.and.arrow.down", title: "Save to camera roll", sub: "Export share card as image") {
                exportCard()
            }
            Rectangle().fill(Color.dsHairLine).frame(height: 1)
            dotsRow(icon: "square.and.arrow.up", title: "Share via…", sub: "iOS share sheet") {
                exportCard()
            }
            Rectangle().fill(Color.dsHairLine).frame(height: 1)
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { showDotsMenu = false }
                onDismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.signalDown)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Skip sharing")
                            .font(.archivo(14, weight: .semibold))
                            .foregroundStyle(Color.signalDown)
                        Text("Workout saved, won't be posted")
                            .font(.archivo(11))
                            .foregroundStyle(Color.signalDown.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
        }
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.dsHairLine, lineWidth: 1))
        .shadow(color: .black.opacity(0.14), radius: 20, y: 8)
    }

    private func dotsRow(icon: String, title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                    Text(sub).font(.archivo(11)).foregroundStyle(Color.inkMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private func shareChip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Font.spaceMono(9, weight: .bold))
                .foregroundStyle(active ? .white : Color.inkMuted)
                .tracking(0.8)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Capsule().fill(active ? Color.pumpAccent : Color.clear))
                .overlay(Capsule().strokeBorder(active ? Color.pumpAccent : Color.dsHairLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var avatarInitial: String {
        String((userName.isEmpty ? "U" : userName).prefix(1)).uppercased()
    }

    private func exportCard() {
        let card = ShareCardView(cardType: .postWorkout(data))
        shareImage = renderShareCard(card, size: CGSize(width: 360, height: 480))
        showDotsMenu = false
        showShareSheet = shareImage != nil
    }

    private func postAndDismiss() {
        Task {
            let item = WorkoutFeedItem(
                userId: Auth.auth().currentUser?.uid ?? "",
                username: Auth.auth().currentUser?.displayName ?? "User",
                templateName: data.workoutName,
                exerciseCount: data.exerciseCount,
                durationSeconds: Int(data.duration),
                caloriesBurned: Int(data.calories),
                musclesWorked: data.musclesWorked.map(\.displayName),
                prCount: data.prCount,
                improvedCount: data.improvedCount,
                totalExercises: data.totalExercises,
                date: Date(),
                caption: caption,
                exercises: data.exercises
            )
            try? await FirestoreService().shareWorkoutToFeed(item)
        }
        onDismiss()
    }
}

// MARK: - Thermal Body Canvas

struct ThermalBodyCanvas: View {
    let muscles: Set<MuscleGroup>
    let showBack: Bool

    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 200, sy = size.height / 480
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { .init(x: x * sx, y: y * sy) }
            let base = Color.primary.opacity(0.07)

            // Base body shapes
            ctx.fill(Path(ellipseIn: CGRect(x: 78*sx, y: 6*sy, width: 44*sx, height: 52*sy)), with: .color(base))
            ctx.fill(Path(roundedRect: CGRect(x: 90*sx, y: 54*sy, width: 20*sx, height: 18*sy), cornerRadius: 4*sx), with: .color(base))

            var torso = Path()
            torso.move(to: pt(60,76)); torso.addQuadCurve(to: pt(56,200), control: pt(54,130))
            torso.addQuadCurve(to: pt(68,310), control: pt(58,260))
            torso.addLine(to: pt(72,340)); torso.addLine(to: pt(128,340)); torso.addLine(to: pt(132,310))
            torso.addQuadCurve(to: pt(144,200), control: pt(142,260))
            torso.addQuadCurve(to: pt(140,76), control: pt(146,130)); torso.closeSubpath()
            ctx.fill(torso, with: .color(base))

            var la = Path(); la.move(to: pt(60,76))
            la.addQuadCurve(to: pt(40,108), control: pt(46,86)); la.addQuadCurve(to: pt(36,180), control: pt(34,140))
            la.addQuadCurve(to: pt(48,240), control: pt(38,220)); la.addLine(to: pt(58,238))
            la.addQuadCurve(to: pt(58,160), control: pt(56,200)); la.addQuadCurve(to: pt(64,88), control: pt(60,110))
            la.closeSubpath(); ctx.fill(la, with: .color(base))

            var ra = Path(); ra.move(to: pt(140,76))
            ra.addQuadCurve(to: pt(160,108), control: pt(154,86)); ra.addQuadCurve(to: pt(164,180), control: pt(166,140))
            ra.addQuadCurve(to: pt(152,240), control: pt(162,220)); ra.addLine(to: pt(142,238))
            ra.addQuadCurve(to: pt(142,160), control: pt(144,200)); ra.addQuadCurve(to: pt(136,88), control: pt(140,110))
            ra.closeSubpath(); ctx.fill(ra, with: .color(base))

            var lf = Path(); lf.move(to: pt(48,240))
            lf.addQuadCurve(to: pt(36,300), control: pt(40,268)); lf.addLine(to: pt(46,302))
            lf.addQuadCurve(to: pt(58,244), control: pt(54,276)); lf.closeSubpath()
            ctx.fill(lf, with: .color(base))

            var rf = Path(); rf.move(to: pt(152,240))
            rf.addQuadCurve(to: pt(164,300), control: pt(160,268)); rf.addLine(to: pt(154,302))
            rf.addQuadCurve(to: pt(142,244), control: pt(146,276)); rf.closeSubpath()
            ctx.fill(rf, with: .color(base))

            var ll = Path(); ll.move(to: pt(72,340))
            ll.addQuadCurve(to: pt(64,440), control: pt(66,390)); ll.addLine(to: pt(90,440))
            ll.addQuadCurve(to: pt(96,350), control: pt(94,400)); ll.closeSubpath()
            ctx.fill(ll, with: .color(base))

            var rl = Path(); rl.move(to: pt(128,340))
            rl.addQuadCurve(to: pt(136,440), control: pt(134,390)); rl.addLine(to: pt(110,440))
            rl.addQuadCurve(to: pt(104,350), control: pt(106,400)); rl.closeSubpath()
            ctx.fill(rl, with: .color(base))

            // Thermal muscle highlights
            func h(_ g: MuscleGroup) -> Double { muscles.contains(g) ? 0.88 : 0 }
            func hmax(_ gs: MuscleGroup...) -> Double { gs.map { h($0) }.max() ?? 0 }
            func fill(_ heat: Double) -> GraphicsContext.Shading { .color(thermalColor(heat)) }

            if !showBack {
                let chest = h(.chest)
                if chest > 0 {
                    var c = Path(); c.move(to: pt(72,92)); c.addQuadCurve(to: pt(74,130), control: pt(68,110))
                    c.addQuadCurve(to: pt(96,138), control: pt(84,140)); c.addLine(to: pt(96,94))
                    c.addQuadCurve(to: pt(72,92), control: pt(84,88)); ctx.fill(c, with: fill(chest))
                    var c2 = Path(); c2.move(to: pt(128,92)); c2.addQuadCurve(to: pt(126,130), control: pt(132,110))
                    c2.addQuadCurve(to: pt(104,138), control: pt(116,140)); c2.addLine(to: pt(104,94))
                    c2.addQuadCurve(to: pt(128,92), control: pt(116,88)); ctx.fill(c2, with: fill(chest))
                }
                let shoulder = hmax(.shoulders, .frontDelts, .sideDelts)
                if shoulder > 0 {
                    var s = Path(); s.move(to: pt(56,80)); s.addQuadCurve(to: pt(42,108), control: pt(46,90))
                    s.addQuadCurve(to: pt(62,112), control: pt(50,114)); s.addQuadCurve(to: pt(64,84), control: pt(66,96))
                    s.closeSubpath(); ctx.fill(s, with: fill(shoulder))
                    var s2 = Path(); s2.move(to: pt(144,80)); s2.addQuadCurve(to: pt(158,108), control: pt(154,90))
                    s2.addQuadCurve(to: pt(138,112), control: pt(150,114)); s2.addQuadCurve(to: pt(136,84), control: pt(134,96))
                    s2.closeSubpath(); ctx.fill(s2, with: fill(shoulder))
                }
                let tri = h(.triceps)
                if tri > 0 {
                    var t = Path(); t.move(to: pt(42,112)); t.addQuadCurve(to: pt(44,168), control: pt(38,140))
                    t.addQuadCurve(to: pt(60,160), control: pt(52,168)); t.addQuadCurve(to: pt(60,114), control: pt(62,136))
                    t.closeSubpath(); ctx.fill(t, with: fill(tri))
                    var t2 = Path(); t2.move(to: pt(158,112)); t2.addQuadCurve(to: pt(156,168), control: pt(162,140))
                    t2.addQuadCurve(to: pt(140,160), control: pt(148,168)); t2.addQuadCurve(to: pt(140,114), control: pt(138,136))
                    t2.closeSubpath(); ctx.fill(t2, with: fill(tri))
                }
                let bic = h(.biceps)
                if bic > 0 {
                    ctx.fill(Path(CGRect(x: 40*sx, y: 120*sy, width: 16*sx, height: 70*sy)), with: fill(bic))
                    ctx.fill(Path(CGRect(x: 144*sx, y: 120*sy, width: 16*sx, height: 70*sy)), with: fill(bic))
                }
                let core = hmax(.abs, .obliques)
                if core > 0 {
                    for i in 0..<3 {
                        let y = 144 + CGFloat(i) * 18
                        ctx.fill(Path(roundedRect: CGRect(x: 86*sx, y: y*sy, width: 28*sx, height: 14*sy), cornerRadius: 3*sx), with: fill(core))
                    }
                }
                let quad = hmax(.quads, .adductors)
                if quad > 0 {
                    var q = Path(); q.move(to: pt(70,340)); q.addQuadCurve(to: pt(66,420), control: pt(64,380))
                    q.addLine(to: pt(92,420)); q.addQuadCurve(to: pt(94,346), control: pt(94,380)); q.closeSubpath()
                    ctx.fill(q, with: fill(quad))
                    var q2 = Path(); q2.move(to: pt(130,340)); q2.addQuadCurve(to: pt(134,420), control: pt(136,380))
                    q2.addLine(to: pt(108,420)); q2.addQuadCurve(to: pt(106,346), control: pt(106,380)); q2.closeSubpath()
                    ctx.fill(q2, with: fill(quad))
                }
            } else {
                let back = hmax(.back, .lats, .upperBack, .traps)
                if back > 0 {
                    var b = Path(); b.move(to: pt(70,102)); b.addQuadCurve(to: pt(72,200), control: pt(66,150))
                    b.addLine(to: pt(100,210)); b.addLine(to: pt(128,200))
                    b.addQuadCurve(to: pt(130,102), control: pt(134,150))
                    b.addQuadCurve(to: pt(100,108), control: pt(118,108))
                    b.addQuadCurve(to: pt(70,102), control: pt(82,108)); ctx.fill(b, with: fill(back))
                }
                let rearDelt = hmax(.shoulders, .rearDelts)
                if rearDelt > 0 {
                    var s = Path(); s.move(to: pt(56,80)); s.addQuadCurve(to: pt(42,108), control: pt(46,90))
                    s.addQuadCurve(to: pt(62,112), control: pt(50,114)); s.addQuadCurve(to: pt(64,84), control: pt(66,96))
                    s.closeSubpath(); ctx.fill(s, with: fill(rearDelt))
                    var s2 = Path(); s2.move(to: pt(144,80)); s2.addQuadCurve(to: pt(158,108), control: pt(154,90))
                    s2.addQuadCurve(to: pt(138,112), control: pt(150,114)); s2.addQuadCurve(to: pt(136,84), control: pt(134,96))
                    s2.closeSubpath(); ctx.fill(s2, with: fill(rearDelt))
                }
                let lb = h(.lowerBack)
                if lb > 0 {
                    ctx.fill(Path(CGRect(x: 78*sx, y: 220*sy, width: 44*sx, height: 60*sy)), with: fill(lb))
                }
                let glute = hmax(.glutes, .hamstrings)
                if glute > 0 {
                    var q = Path(); q.move(to: pt(70,340)); q.addQuadCurve(to: pt(66,420), control: pt(64,380))
                    q.addLine(to: pt(92,420)); q.addQuadCurve(to: pt(94,346), control: pt(94,380)); q.closeSubpath()
                    ctx.fill(q, with: fill(glute))
                    var q2 = Path(); q2.move(to: pt(130,340)); q2.addQuadCurve(to: pt(134,420), control: pt(136,380))
                    q2.addLine(to: pt(108,420)); q2.addQuadCurve(to: pt(106,346), control: pt(106,380)); q2.closeSubpath()
                    ctx.fill(q2, with: fill(glute))
                }
            }
        }
    }

    private func thermalColor(_ t: Double) -> Color {
        let t = max(0, min(1, t))
        let stops: [(Double, Double, Double, Double)] = [
            (0.00, 240, 236, 226),
            (0.20, 236, 214, 184),
            (0.45, 226, 170, 124),
            (0.70, 212, 118,  88),
            (1.00, 192,  72,  60),
        ]
        for i in 0..<stops.count - 1 {
            let (a, ar, ag, ab) = stops[i]
            let (b, br, bg, bb) = stops[i + 1]
            if t <= b {
                let k = (t - a) / (b - a)
                return Color(red: (ar + (br-ar)*k)/255, green: (ag + (bg-ag)*k)/255, blue: (ab + (bb-ab)*k)/255)
            }
        }
        return Color(red: 192/255, green: 72/255, blue: 60/255)
    }
}

// MARK: - Legacy helpers

struct CompletionStatCard: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.display(20)).foregroundStyle(Color.pumpAccent)
            Text(value).font(.display(20))
            Text(title).font(.mono(11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(Color.surf)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        computeLayout(proposal: proposal, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (i, pos) in result.positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }
    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxW = proposal.width ?? .infinity
        var positions: [CGPoint] = []; var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x + sz.width > maxW && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            positions.append(.init(x: x, y: y)); rowH = max(rowH, sz.height); x += sz.width + spacing
        }
        return (CGSize(width: maxW, height: y + rowH), positions)
    }
}

#Preview {
    WorkoutCompletionView(data: .preview, userName: "Vasanth", onDismiss: {})
}
