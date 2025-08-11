import Foundation

struct LASKOAuthSession {
    let tlsAddress: String
    let sessionToken: String
    let signature: String
    let timestamp: Int64
    let expiresAt: Int64
    let permissions: [String]
}

struct PostSignature {
    let signature: String
    let tlsAddress: String
    let timestamp: Int64
    let content: String
    let sessionToken: String
} 