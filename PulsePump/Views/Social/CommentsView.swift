import SwiftUI

struct CommentsView: View {
    let postId: String
    @State private var viewModel = SocialViewModel()
    @State private var comments: [FeedComment] = []
    @State private var newCommentText = ""
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if comments.isEmpty {
                    ContentUnavailableView(
                        "No Comments",
                        systemImage: "bubble.right",
                        description: Text("Be the first to comment.")
                    )
                } else {
                    List(comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("@\(comment.username)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.pumpPrimary)
                                Spacer()
                                Text(comment.date, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(comment.text)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 2)
                    }
                    .listStyle(.plain)
                }

                // Compose area
                Divider()
                HStack(spacing: 12) {
                    TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                        .lineLimit(1...3)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        postComment()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color(.systemGray3) : Color.pumpPrimary)
                    }
                    .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadComments()
            }
        }
    }

    private func loadComments() async {
        isLoading = true
        comments = await viewModel.fetchComments(postId: postId)
        isLoading = false
    }

    private func postComment() {
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        newCommentText = ""
        Task {
            await viewModel.postComment(postId: postId, text: text)
            comments = await viewModel.fetchComments(postId: postId)
        }
    }
}
