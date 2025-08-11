import Foundation

struct LASKOAuthRequest {
    let appName: String
    let appId: String
    let permissions: [String]
    let callbackURL: String
    let username: String?
    let nonce: String?
    
    var permissionDescriptions: [String] {
        permissions.map { permission in
            switch permission {
            case "post": return "Create posts on your behalf"
            case "read": return "Access your TLS address"
            default: return permission
            }
        }
    }
} 