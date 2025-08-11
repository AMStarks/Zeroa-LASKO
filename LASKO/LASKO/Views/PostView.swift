import SwiftUI

struct PostView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading) {
                    Text(post.author)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                                    Text(formatTimestamp(post.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Rank icon based on post rank
                Image(systemName: rankIcon(for: post.userRank))
                    .foregroundColor(.orange)
                    .shadow(color: Color.orange.opacity(0.4), radius: 4, x: 0, y: 2)
            }
            
            Text(post.content)
                .font(.body)
                .foregroundColor(.primary)
            
            HStack {
                Button(action: {
                    // Handle like
                }) {
                    HStack {
                        Image(systemName: "heart")
                            .foregroundColor(.orange)
                        Text("\(post.likes)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    // Handle comment
                }) {
                    HStack {
                        Image(systemName: "message")
                            .foregroundColor(.orange)
                                        Text("\(post.replies)")
                    .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    // Handle share
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.orange)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func rankIcon(for rank: String) -> String {
        switch rank.lowercased() {
        case "bronze": return "medal.fill"
        case "silver": return "medal.fill"
        case "gold": return "crown.fill"
        case "platinum": return "diamond.fill"
        case "diamond": return "diamond.fill"
        default: return "medal.fill"
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
} 