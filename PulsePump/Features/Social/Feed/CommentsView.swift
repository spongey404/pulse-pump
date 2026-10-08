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

    var body: some View {
        VStack(spacing: 0) {
            condensedPostHeader

            ZStack(alignment: .top) {
                Color(hex: "#1F1C19").opacity(0.45)
                    .background(.ultraThinMaterial)
                    .onTapGesture { dismiss() }

                VStack(spacing: 0) {
                    Capsule().fill(Color.ruleStrong).frame(width: 36, height: 4)
                        .padding(.top, 10).padding(.bottom, 10)

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
                                ForEach(comments) { comment in
                                    commentRow(comment)
                                }
                            }
                        }
                    }

                    Divider().overlay(Color.dsHairLine)
                    composerRow
                }
                .background(Color.canvasBg)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 8, style: .continuous))
            }
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
        HStack(alignment: .center, spacing: 10) {
            Avatar(initial: displayName, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(displayName).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                Text((item.templateName ?? "WORKOUT").uppercased()).font(Font.spaceMono(9)).foregroundStyle(Color.inkMuted)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 16)).foregroundStyle(Color.inkMuted).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func commentRow(_ comment: FeedComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Avatar(initial: comment.username, size: 32, showBorder: false)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(comment.username).font(.archivo(14, weight: .bold)).foregroundStyle(Color.inkPrimary)
                    Text(comment.date, style: .relative).font(Font.spaceMono(9)).foregroundStyle(Color.inkMuted)
                }
                Text(comment.text).font(.archivo(14)).foregroundStyle(Color.inkPrimary).lineSpacing(3)
            }
            Spacer(minLength: 0)
            Button { commentToReport = comment } label: {
                Image(systemName: "ellipsis").font(.system(size: 14)).foregroundStyle(Color.inkMuted).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Comment options")
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
    }

    private var composerRow: some View {
        HStack(spacing: 10) {
            TextField("Add a comment", text: $newCommentText, axis: .vertical)
                .font(.archivo(14))
                .lineLimit(1...3)
            Button(action: postComment) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(trimmed.isEmpty || isPosting ? Color.inkFaint : Color.accentInk)
            }
            .disabled(trimmed.isEmpty || trimmed.count > 500 || isPosting)
            .accessibilityLabel("Send comment")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
