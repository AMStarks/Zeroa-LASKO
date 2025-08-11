import Foundation

struct Post: Identifiable, Codable {
    let id: String
    let content: String
    let author: String
    let timestamp: Date
    let likes: Int
    let replies: Int
    let isLiked: Bool
    let userRank: String // Bronze, Silver, Gold, Platinum, Diamond
    
    init(id: String = UUID().uuidString, content: String, author: String, timestamp: Date = Date(), likes: Int = 0, replies: Int = 0, isLiked: Bool = false, userRank: String = "Bronze") {
        self.id = id
        self.content = content
        self.author = author
        self.timestamp = timestamp
        self.likes = likes
        self.replies = replies
        self.isLiked = isLiked
        self.userRank = userRank
    }
}

// Mock data for development
extension Post {
    static let mockPosts = [
        Post(content: "Just deployed my first decentralized social media post! 🚀 #LASKO #Telestai", author: "crypto_dev", likes: 42, replies: 5, userRank: "Diamond"),
        Post(content: "Privacy shouldn't be a luxury. That's why I'm building on LASKO.", author: "privacy_advocate", likes: 28, replies: 3, userRank: "Platinum"),
        Post(content: "The future of social media is decentralized. No more algorithm manipulation!", author: "web3_builder", likes: 67, replies: 12, userRank: "Gold"),
        Post(content: "Testing the LASKO platform. So far, so good! The UI is clean and the experience is smooth.", author: "early_adopter", likes: 15, replies: 2, userRank: "Silver"),
        Post(content: "Blockchain-powered social media is the way forward. LASKO is leading the charge.", author: "blockchain_expert", likes: 89, replies: 8, userRank: "Bronze")
    ]
} 