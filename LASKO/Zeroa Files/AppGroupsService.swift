import Foundation

class AppGroupsService {
    static let shared = AppGroupsService()
    
    // App Group identifier - both apps will use this
    private let appGroupIdentifier = "group.com.telestai.zeroa-lasko"
    private let sharedDefaults: UserDefaults?
    
    init() {
        sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)
        print("🔧 AppGroupsService initialized with group: \(appGroupIdentifier)")
        
        // Debug: Check if App Groups container is accessible
        if let defaults = sharedDefaults {
            print("✅ Zeroa: App Groups container accessible")
            // Test write/read
            defaults.set("test_from_zeroa", forKey: "test_key_zeroa")
            if let testValue = defaults.string(forKey: "test_key_zeroa") {
                print("✅ Zeroa: App Groups read/write test successful")
                defaults.removeObject(forKey: "test_key_zeroa")
            } else {
                print("❌ Zeroa: App Groups read/write test failed")
            }
        } else {
            print("❌ Zeroa: App Groups container not accessible")
        }
    }
    
    // MARK: - LASKO Authentication Request
    
    func storeLASKOAuthRequest(_ request: LASKOAuthRequest) {
        let requestData: [String: Any] = [
            "appName": request.appName,
            "appId": request.appId,
            "permissions": request.permissions,
            "callbackURL": request.callbackURL,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sharedDefaults?.set(requestData, forKey: "lasko_auth_request")
        print("📤 Stored LASKO auth request: \(request.appName)")
    }
    
    func getLASKOAuthRequest() -> LASKOAuthRequest? {
        print("🔍 Attempting to retrieve LASKO auth request from App Groups...")
        
        // Debug: Check what keys are available
        if let defaults = sharedDefaults {
            let allKeys = defaults.dictionaryRepresentation().keys
            print("🔍 Zeroa: All keys in App Groups container: \(allKeys)")
            
            for key in allKeys {
                if let value = defaults.object(forKey: key) {
                    print("📊 Zeroa: Key '\(key)' = \(value)")
                }
            }
        }
        
        guard let requestData = sharedDefaults?.dictionary(forKey: "lasko_auth_request") else {
            print("❌ No LASKO auth request found in App Groups")
            return nil
        }
        
        print("📦 Found request data: \(requestData)")
        
        guard let appName = requestData["appName"] as? String,
              let appId = requestData["appId"] as? String,
              let permissions = requestData["permissions"] as? [String],
              let callbackURL = requestData["callbackURL"] as? String else {
            print("❌ Invalid LASKO auth request data")
            return nil
        }
        
        print("📥 Retrieved LASKO auth request: \(appName)")
        return LASKOAuthRequest(
            appName: appName,
            appId: appId,
            permissions: permissions,
            callbackURL: callbackURL
        )
    }
    
    // MARK: - LASKO Authentication Response
    
    func storeLASKOAuthResponse(_ session: LASKOAuthSession) {
        let responseData: [String: Any] = [
            "tlsAddress": session.tlsAddress,
            "sessionToken": session.sessionToken,
            "signature": session.signature,
            "timestamp": session.timestamp,
            "expiresAt": session.expiresAt,
            "permissions": session.permissions,
            "responseTimestamp": Date().timeIntervalSince1970
        ]
        
        sharedDefaults?.set(responseData, forKey: "lasko_auth_response")
        print("📤 Stored LASKO auth response for: \(session.tlsAddress)")
    }
    
    func getLASKOAuthResponse() -> LASKOAuthSession? {
        guard let responseData = sharedDefaults?.dictionary(forKey: "lasko_auth_response") else {
            return nil
        }
        
        guard let tlsAddress = responseData["tlsAddress"] as? String,
              let sessionToken = responseData["sessionToken"] as? String,
              let signature = responseData["signature"] as? String,
              let timestamp = responseData["timestamp"] as? Int64,
              let expiresAt = responseData["expiresAt"] as? Int64,
              let permissions = responseData["permissions"] as? [String] else {
            print("❌ Invalid LASKO auth response data")
            return nil
        }
        
        print("📥 Retrieved LASKO auth response for: \(tlsAddress)")
        return LASKOAuthSession(
            tlsAddress: tlsAddress,
            sessionToken: sessionToken,
            signature: signature,
            timestamp: timestamp,
            expiresAt: expiresAt,
            permissions: permissions
        )
    }
    
    // MARK: - Cleanup
    
    func clearAuthRequest() {
        sharedDefaults?.removeObject(forKey: "lasko_auth_request")
        print("🧹 Cleared LASKO auth request")
    }
    
    func clearAuthResponse() {
        sharedDefaults?.removeObject(forKey: "lasko_auth_response")
        print("🧹 Cleared LASKO auth response")
    }
    
    func clearAll() {
        clearAuthRequest()
        clearAuthResponse()
        print("🧹 Cleared all App Groups data")
    }
    
    // MARK: - Status Checking
    
    func hasPendingAuthRequest() -> Bool {
        return sharedDefaults?.object(forKey: "lasko_auth_request") != nil
    }
    
    func hasAuthResponse() -> Bool {
        return sharedDefaults?.object(forKey: "lasko_auth_response") != nil
    }
} 