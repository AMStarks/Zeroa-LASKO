import SwiftUI

struct FeedView: View {
    @State private var posts: [Post] = []
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(posts, id: \.id) { post in
                    PostView(post: post)
                }
            }
            .padding()
        }
        .refreshable {
            await loadPosts()
        }
        .onAppear {
            Task {
                await loadPosts()
            }
        }
    }
    
    private func loadPosts() async {
        isLoading = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Sample data
        posts = [
            Post(content: "Just posted my first LASKO update! 🚀", author: "Alice", likes: 42, replies: 5, userRank: "Gold"),
            Post(content: "The blockchain integration is working perfectly. Love the new features!", author: "Bob", likes: 28, replies: 3, userRank: "Silver"),
            Post(content: "Can't believe how fast LASKO is growing. The community is amazing!", author: "Charlie", likes: 67, replies: 12, userRank: "Diamond")
        ]
        
        isLoading = false
    }
} 