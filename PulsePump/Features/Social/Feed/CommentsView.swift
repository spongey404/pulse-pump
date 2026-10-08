import SwiftUI

/// 6c — comments, presented as a sheet sliding up over the post. The spec has the post's
/// header/photo staying visible above a blurred scrim with the sheet starting at `top:
/// 230px`; SwiftUI's sheet presentation can't overlay live content from the presenting
/// view, so this renders a condensed copy of the post header at the top of a
/// `.fullScreenCover` to preserve that visual — not the same view instance, but the same
/// read.
struct CommentsView: View {
    let item: WorkoutFeedItem
    @State private var viewModel = SocialViewModel()
    @State private var comments: [FeedComment] = []
    @State private var newCommentText = ""
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

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

                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .task { await loadComments() }
    }

    private var condensedPostHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Avatar(initial: item.username, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.username).font(.archivo(14, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                Text((item.templateName ?? "WORKOUT").uppercased()).font(Font.spaceMono(9)).foregroundStyle(Color.inkMuted)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 16)).foregroundStyle(Color.inkMuted).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
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
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart").font(.system(size: 14)).foregroundStyle(Color.inkMuted)
                        Text("0").font(Font.spaceMono(10)).foregroundStyle(Color.inkMuted)
                    }
                    Text("REPLY").font(Font.spaceMono(9, weight: .bold)).tracking(1).foregroundStyle(Color.inkMuted)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var composerRow: some View {
        HStack(spacing: 10) {
            TextField("Add a comment", text: $newCommentText, axis: .vertical)
                .font(.archivo(14))
                .lineLimit(1...3)
            Button(action: postComment) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.inkFaint : Color.accentInk)
            }
            .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.canvasBg)
    }

    private func loadComments() async {
        isLoading = true
        comments = await viewModel.fetchComments(postId: item.id)
        isLoading = false
    }

    private func postComment() {
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        newCommentText = ""
        Task {
            await viewModel.postComment(postId: item.id, text: text)
            comments = await viewModel.fetchComments(postId: item.id)
        }
    }
}
