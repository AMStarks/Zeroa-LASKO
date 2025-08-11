import Foundation
import UIKit

@MainActor
class LASKOService: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isConnectedToTelestai = false
    @Published var isAuthenticatedWithZeroa = false
    @Published var currentTLSAddress: String?
    
    private let baseURL = "http://localhost:3000/api"
    private let appGroupsService = AppGroupsService.shared
    
    init() {
        loadMockData()
        // Do not auto-check authentication on init; allow explicit user-triggered flow
    }
    
    // MARK: - Zeroa Integration
    
    func checkZeroaAuthentication() {
        print("🔍 LASKO: Checking Zeroa authentication...")
        
        // Check for existing auth response from Zeroa
        if let authResponse = appGroupsService.getLASKOAuthResponse() {
            print("✅ LASKO: Found existing auth response from Zeroa")
            DispatchQueue.main.async {
                self.isAuthenticatedWithZeroa = true
                self.currentTLSAddress = authResponse.tlsAddress
            }
            print("🔑 LASKO: TLS Address: \(authResponse.tlsAddress)")
        } else {
            print("❌ LASKO: No auth response found from Zeroa")
            DispatchQueue.main.async {
                self.isAuthenticatedWithZeroa = false
                self.currentTLSAddress = nil
            }
        }
    }
    
    func requestZeroaAuthentication() {
        print("🔍 LASKO: Requesting Zeroa authentication...")
        
        // Create auth request
        let authRequest = LASKOAuthRequest(
            appName: "LASKO",
            appId: "com.telestai.lasko",
            permissions: ["post", "read"],
            callbackURL: "lasko://auth/callback",
            username: "LASKO User",
            nonce: nil
        )
        
        // Store request in App Groups
        appGroupsService.storeLASKOAuthRequest(authRequest)
        print("📤 LASKO: Auth request stored in App Groups")
        
        // Open Zeroa app
        if let zeroaURL = URL(string: "zeroa://auth/request") {
            if UIApplication.shared.canOpenURL(zeroaURL) {
                UIApplication.shared.open(zeroaURL) { success in
                    if success {
                        print("✅ LASKO: Successfully opened Zeroa app")
                    } else {
                        print("❌ LASKO: Failed to open Zeroa app")
                    }
                }
            } else {
                print("❌ LASKO: Cannot open Zeroa app - URL scheme not registered")
                print("💡 LASKO: This is expected if Zeroa app is not installed. The auth request has been stored and will be processed when Zeroa is available.")
            }
        }
    }
    
    func checkForAuthResponse() {
        print("🔍 LASKO: Checking for auth response...")
        
        if let authResponse = appGroupsService.getLASKOAuthResponse() {
            print("✅ LASKO: Found auth response from Zeroa")
            DispatchQueue.main.async {
                self.isAuthenticatedWithZeroa = true
                self.currentTLSAddress = authResponse.tlsAddress
                
                // Clear the response after processing
                self.appGroupsService.clearAuthResponse()
                
                print("🔑 LASKO: Authentication successful with TLS address: \(authResponse.tlsAddress)")
            }
        }
    }

    // Lightweight check used by UI to detect if a response already exists without changing state
    func hasExistingAuthResponse() -> Bool {
        return appGroupsService.getLASKOAuthResponse() != nil
    }
    
    // MARK: - Mock Data for Development
    func loadMockData() {
        posts = Post.mockPosts
    }
    
    // MARK: - API Methods
    
    func fetchPosts() async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        // Check authentication first
        if !isAuthenticatedWithZeroa {
            print("⚠️ LASKO: Not authenticated with Zeroa - requesting authentication")
            requestZeroaAuthentication()
            isLoading = false
            return
        }
        
        // For now, just use mock data
        DispatchQueue.main.async {
            self.posts = Post.mockPosts
            self.isLoading = false
        }
    }
    
    // Legacy helper kept for compatibility with older call sites
    func createPost(content: String, author: String) async -> Bool {
        await createPost(content: content)
    }
    
    // MARK: - New Create Post (parity with older app)
    struct CreatePostRequest: Codable {
        let content: String
        let tlsAddress: String
        let signature: String
        let timestamp: Int64
        let postType: String
        let zeroaSessionId: String?
        let zeroaVersion: String?
    }
    
    struct LASKOPostSignature {
        let publicKey: String
        let signature: String
        let timestamp: Int64
    }
    
    private func signPost(_ content: String, address: String) -> LASKOPostSignature {
        // Placeholder signing – replace with real signing when available
        let ts = Int64(Date().timeIntervalSince1970 * 1000)
        let sig = "mock-signature-\(ts)"
        return LASKOPostSignature(publicKey: address, signature: sig, timestamp: ts)
    }
    
    func createPost(content: String) async -> Bool {
        // Validation
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard trimmed.count <= 1000 else { return false }
        
        // Require Zeroa auth to get TLS address
        guard isAuthenticatedWithZeroa, let tlsAddress = currentTLSAddress else {
            print("❌ LASKO: Cannot create post - not authenticated with Zeroa")
            return false
        }
        
        // Build payload (mock signature for now)
        let sig = signPost(trimmed, address: tlsAddress)
        // Prepare payload (currently unused, kept for parity with backend format)
        let _ = CreatePostRequest(
            content: trimmed,
            tlsAddress: sig.publicKey,
            signature: sig.signature,
            timestamp: sig.timestamp,
            postType: "free",
            zeroaSessionId: nil,
            zeroaVersion: "1.0.0"
        )
        
        // For now, optimistically insert into local feed and return true
        DispatchQueue.main.async {
            let newPost = Post(
                content: trimmed,
                author: tlsAddress,
                timestamp: Date(),
                likes: 0,
                replies: 0,
                userRank: "Bronze"
            )
            self.posts.insert(newPost, at: 0)
        }
        
        // If you want to hit a backend later, uncomment and fill baseURL
        // do {
        //     var req = URLRequest(url: URL(string: "\(baseURL)/posts")!)
        //     req.httpMethod = "POST"
        //     req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        //     let data = try JSONEncoder().encode(body)
        //     req.httpBody = data
        //     _ = try await URLSession.shared.data(for: req)
        // } catch { print("⚠️ Post send failed: \(error)") }
        
        return true
    }
    
    func likePost(_ post: Post) async {
        // Mock implementation for now
        DispatchQueue.main.async {
            if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                self.posts[index] = Post(
                    id: post.id,
                    content: post.content,
                    author: post.author,
                    timestamp: post.timestamp,
                    likes: post.likes + 1,
                    replies: post.replies,
                    isLiked: true,
                    userRank: post.userRank
                )
            }
        }
    }
    
    // MARK: - Blockchain Methods (Placeholder)
    
    func getBlockchainInfo() async -> TelestaiBlock? {
        // Placeholder for future implementation
        return nil
    }
    
    func getNextBlockTiming() async -> (height: Int, estimatedTime: Date)? {
        // Placeholder for future implementation
        return nil
    }
    
    func getAddressBalance(address: String) async -> TelestaiAddress? {
        // Placeholder for future implementation
        return nil
    }
    
    func signMessage(message: String, address: String, privateKey: String) async -> TelestaiMessage? {
        // Placeholder for future implementation
        return nil
    }
    
    func verifyMessage(message: String, signature: String, address: String) async -> Bool {
        // Placeholder for future implementation
        return false
    }
}

// MARK: - Placeholder Models for Telestai
struct TelestaiBlock {
    let height: Int
    let hash: String
    let timestamp: Int
    let transactions: [String]
}

struct TelestaiAddress {
    let address: String
    let balance: Double
    let unconfirmedBalance: Double
    let txCount: Int
}

struct TelestaiMessage {
    let message: String
    let signature: String
    let address: String
    let timestamp: Int
}
