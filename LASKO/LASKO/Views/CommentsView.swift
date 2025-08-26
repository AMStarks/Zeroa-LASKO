import SwiftUI

struct CommentsView: View {
    let postId: String
    let sequentialCode: String?
    @EnvironmentObject var laskoService: LASKOService
    @State private var replyText: String = ""
    @State private var isPosting: Bool = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            List {
                if let error = error {
                    Text(error).foregroundColor(.red)
                }
                if let code = sequentialCode, let replies = laskoService.repliesByCode[code], !replies.isEmpty {
                    // Render with simple nesting by parentCode if available
                    let topLevel = replies.filter { ($0.parentCode ?? "") == code || ($0.parentCode ?? "").isEmpty }
                    ForEach(topLevel) { r in
                        CommentRow(comment: r, all: replies, depth: 0)
                    }
                } else {
                    Text("No replies yet.").foregroundColor(.secondary)
                }
            }
            .listStyle(.plain)

            // Composer
            HStack(spacing: 8) {
                TextField("Write a reply…", text: $replyText)
                    .textFieldStyle(.roundedBorder)
                Button(isPosting ? "Posting…" : "Reply") {
                    Task { await postReply() }
                }
                .disabled(isPosting || replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
        }
        .onAppear {
            if let code = sequentialCode {
                Task { await laskoService.fetchComments(forSequentialCode: code) }
            }
        }
    }

    private func postReply() async {
        guard !isPosting else { return }
        isPosting = true
        defer { isPosting = false }
        if let code = sequentialCode {
            let ok = await laskoService.createComment(content: replyText, parentSequentialCode: code)
            if ok { await laskoService.fetchComments(forSequentialCode: code) }
            if ok { replyText = "" } else { error = "Failed to post reply" }
            return
        }
        let ok = await laskoService.createPost(content: replyText)
        if ok { replyText = "" } else { error = "Failed to post reply" }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}


struct CommentRow: View {
    let comment: Post
    let all: [Post]
    let depth: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(comment.author).font(.subheadline).foregroundColor(.primary)
                Spacer()
                Text(formatTimestamp(comment.timestamp)).font(.caption).foregroundColor(.secondary)
            }
            Text(comment.content).font(.body)
            // Children
            let children = all.filter { $0.parentCode == comment.id }
            if !children.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(children) { c in
                        CommentRow(comment: c, all: all, depth: depth + 1)
                    }
                }
                .padding(.leading, CGFloat((depth + 1) * 16))
            }
        }
        .padding(.vertical, 4)
    }
    private func formatTimestamp(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
