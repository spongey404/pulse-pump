import SwiftUI

/// 6c — comments, presented as a sheet sliding up over the post. The spec has the post's
/// header staying visible above a blurred scrim with the sheet starting at `top: 230px`;
/// SwiftUI's sheet presentation can't overlay live content from the presenting view, so this
/// renders a condensed copy of the post header at the top of a `.fullScreenCover`.
///
/// Uses the shared view model, so the comment count on the feed card updates as soon as a comment
/// is posted (and rolls back if the write fails).
struct CommentsView: View {
    let item: WorkoutFeedItem
    var viewModel: SocialViewModel
    @State private var newCommentText = ""
    @State private var isLoading = false
    @State private var isPosting = false
    @State private var commentToReport: FeedComment?
    @Environment(\.dismiss) private var dismiss

    private var comments: [FeedComment] { viewModel.comments[item.id] ?? [] }
    private var displayName: String { item.username.isEmpty ? item.handle : item.username }
    private var trimmed: String { newCommentText.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Comment hearts need a per-comment like count in Firestore (`FeedComment` has none), so the heart stays off until it exists.
    static let commentLikesAvailable = false

    @FocusState private var composerFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            // The post behind the sheet: who posted what, and its body-map block.
            VStack(spacing: 0) {
                condensedPostHeader
                Color.surf2.frame(height: 260)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.canvasBg)

            Color(hex: "#151A21").opacity(0.45)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                Capsule().fill(Color.ruleStrong).frame(width: 36, height: 4).padding(.top, 8)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("COMMENTS").font(.archivo(20, weight: .black)).foregroundStyle(Color.inkPrimary)
                    Text("\(comments.count)").font(.spaceMono(10)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }

                if isLoading && comments.isEmpty {
                    SkeletonRows(count: 3, rowHeight: 60).padding(.horizontal, 16)
                    Spacer()
                } else if comments.isEmpty {
                    VStack(spacing: 6) {
                        Text("No comments yet").font(.archivo(15, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                        Text("Be the first to say something.").font(.archivo(13)).foregroundStyle(Color.inkMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(comments) { comment in commentRow(comment) }
                        }
                    }
                }

                composerRow
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.canvasBg)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 14, style: .continuous))
            .padding(.top, 170)
            .ignoresSafeArea(edges: .bottom)
        }
        .background(Color.canvasBg.ignoresSafeArea())
        .task {
            isLoading = true
            await viewModel.loadComments(postId: item.id)
            isLoading = false
        }
        .confirmationDialog("Comment", isPresented: Binding(get: { commentToReport != nil }, set: { if !$0 { commentToReport = nil } }), presenting: commentToReport) { comment in
            if comment.userId == viewModel.currentUid {
                Button("Delete comment", role: .destructive) { Task { await viewModel.deleteComment(postId: item.id, commentId: comment.id) } }
            } else {
                Button("Report comment", role: .destructive) { Task { await viewModel.reportComment(postId: item.id, commentId: comment.id) } }
                if item.userId == viewModel.currentUid {
                    Button("Delete comment", role: .destructive) { Task { await viewModel.deleteComment(postId: item.id, commentId: comment.id) } }
                }
            }
        }
    }

    private var condensedPostHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            tile(displayName, size: 38, radius: 11, fill: Color.surf2, ink: Color.inkSecondary, font: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(displayName).font(.archivo(16, weight: .bold)).foregroundStyle(Color.inkPrimary)
                Text("\((item.templateName ?? "Workout")) · \(postAge)").font(.archivo(12)).foregroundStyle(Color.inkMuted)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 12)
    }

    private var postAge: String {
        let f = RelativeDateTimeFormatter(); f.dateTimeStyle = .named; f.unitsStyle = .full
        return f.localizedString(for: item.date, relativeTo: Date()).capitalized
    }

    private func tile(_ name: String, size: CGFloat, radius: CGFloat, fill: Color, ink: Color, font: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
            .frame(width: size, height: size)
            .overlay(Text(name.prefix(1).uppercased()).font(.archivo(font, weight: .black)).foregroundStyle(ink))
    }

    private func commentRow(_ comment: FeedComment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            tile(comment.username, size: 32, radius: 9, fill: Color.surf2, ink: Color.inkSecondary, font: 13)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(comment.username).font(.archivo(15, weight: .bold)).foregroundStyle(Color.inkPrimary)
                    Text(SocialAge.short(comment.date)).font(.spaceMono(8)).tracking(1.5).foregroundStyle(Color.inkMuted)
                }
                Text(comment.text).font(.archivo(14)).foregroundStyle(Color.inkPrimary)
                    .cssLineHeight(fontName: "Archivo-Regular", size: 14, multiple: 1.45)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                HStack(spacing: 16) {
                    if Self.commentLikesAvailable {
                        Text("♡").font(.spaceMono(9, weight: .bold)).foregroundStyle(Color.inkMuted)
                    }
                    Button { reply(to: comment) } label: {
                        Text("REPLY").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reply to \(comment.username)")
                    Button { commentToReport = comment } label: {
                        Text("···").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(Color.inkMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Comment options")
                }
                .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
    }

    private func reply(to comment: FeedComment) {
        let name = comment.handle.isEmpty ? comment.username : comment.handle
        newCommentText = "@\(name) "
        composerFocused = true
    }

    /// Docked in the sheet: your tile, the field (sunken, radius 8), and POST once there is something to send.
    private var composerRow: some View {
        HStack(spacing: 10) {
            tile(viewModel.myName, size: 32, radius: 9, fill: Color.oreAccent, ink: .white, font: 13)
            TextField("Add a comment", text: $newCommentText, axis: .vertical)
                .font(.archivo(14))
                .lineLimit(1...3)
                .focused($composerFocused)
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
                .background(Color.surf2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            if !trimmed.isEmpty {
                Button(action: postComment) {
                    Text("POST").font(.spaceMono(9, weight: .bold)).tracking(1.5).foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(height: 32)
                        .background { AccentFill() }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .opacity(isPosting || trimmed.count > 500 ? 0.5 : 1)
                }
                .buttonStyle(.plain)
                .disabled(isPosting || trimmed.count > 500)
                .accessibilityLabel("Send comment")
            }
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 30)
        .overlay(alignment: .top) { Rectangle().fill(Color.dsHairLine).frame(height: 1) }
        .background(Color.canvasBg)
    }

    private func postComment() {
        let text = trimmed
        guard !text.isEmpty else { return }
        isPosting = true
        Task {
            // The field is only cleared once the comment is saved, so a failed one isn't lost.
            if await viewModel.postComment(postId: item.id, text: text) { newCommentText = "" }
            isPosting = false
        }
    }
}
