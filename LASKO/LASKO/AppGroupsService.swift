import Foundation

class AppGroupsService {
    static let shared = AppGroupsService()
    
    // App Group identifier - both apps will use this
    private let appGroupIdentifier = "group.com.telestai.zeroa-lasko"
    let sharedDefaults: UserDefaults?
    
    init() {
        sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)
        print("🔧 LASKO: AppGroupsService initialized with group: \(appGroupIdentifier)")
        
        // Debug: Check if App Groups container is accessible
        if let defaults = sharedDefaults {
            print("✅ LASKO: App Groups container accessible")
            // Test write/read
            defaults.set("test_from_lasko", forKey: "test_key_lasko")
            if let testValue = defaults.string(forKey: "test_key_lasko") {
                print("✅ LASKO: App Groups read/write test successful")
                defaults.removeObject(forKey: "test_key_lasko")
            } else {
                print("❌ LASKO: App Groups read/write test failed")
            }
            
            // Debug: List all existing keys
            let allKeys = defaults.dictionaryRepresentation().keys
            print("🔍 LASKO: Existing keys in App Groups: \(Array(allKeys))")
        } else {
            print("❌ LASKO: App Groups container not accessible")
            print("🔍 LASKO: This might be due to:")
            print("  - App Groups not configured in entitlements")
            print("  - Provisioning profile doesn't include App Groups")
            print("  - App Groups identifier mismatch")
        }
    }
    
    // MARK: - LASKO Authentication Request
    
    func storeLASKOAuthRequest(_ request: LASKOAuthRequest) {
        let nonce = UUID().uuidString
        let issuedAt = Date().timeIntervalSince1970
        let expiresAt = issuedAt + 120
        let requestData: [String: Any] = [
            "appName": request.appName,
            "appId": request.appId,
            "permissions": request.permissions,
            "callbackURL": request.callbackURL,
            "username": request.username as Any,
            "timestamp": issuedAt,
            "nonce": nonce,
            "expiresAt": expiresAt
        ]
        
        // Write to App Groups
        if let defaults = sharedDefaults {
            defaults.set(requestData, forKey: "lasko_auth_request")
            defaults.synchronize()
            print("📤 LASKO: Auth request stored in App Groups for: \(request.appName)")
            
            // Debug: Verify storage
            if let storedData = defaults.dictionary(forKey: "lasko_auth_request") {
                print("✅ LASKO: Auth request verified in App Groups: \(storedData)")
            } else {
                print("❌ LASKO: Auth request not found in App Groups after storage")
            }
        } else {
            print("❌ LASKO: Cannot store auth request - App Groups not accessible")
        }
        
        // ALSO write to shared file as fallback
        let fileSuccess = writeToSharedFile(key: "lasko_auth_request", data: requestData)
        if fileSuccess {
            print("📤 LASKO: Auth request also stored in shared file for: \(request.appName)")
        } else {
            print("⚠️ LASKO: Failed to store auth request in shared file")
        }
    }
    
    func getLASKOAuthRequest() -> LASKOAuthRequest? {
        print("🔍 LASKO: Attempting to retrieve LASKO auth request from App Groups...")
        
        // Debug: List all keys in App Groups
        if let defaults = sharedDefaults {
            let allKeys = defaults.dictionaryRepresentation().keys
            print("🔍 LASKO: All keys in App Groups: \(Array(allKeys))")
            
            for key in allKeys {
                if let value = defaults.object(forKey: key) {
                    print("📊 LASKO: Key '\(key)' = \(value)")
                }
            }
        }
        
        // First try App Groups
        if let requestData = sharedDefaults?.dictionary(forKey: "lasko_auth_request") {
            print("📦 LASKO: Found request data in App Groups: \(requestData)")
            
            guard let appName = requestData["appName"] as? String,
                  let appId = requestData["appId"] as? String,
                  let permissions = requestData["permissions"] as? [String],
                  let callbackURL = requestData["callbackURL"] as? String else {
                print("❌ LASKO: Invalid LASKO auth request data from App Groups")
                return nil
            }
            
            // whitelist callback
            guard isAllowedCallback(callbackURL) else {
                print("❌ LASKO: Disallowed callback URL: \(callbackURL)")
                return nil
            }
            // TTL
            let now = Date().timeIntervalSince1970
            if let exp = requestData["expiresAt"] as? Double, now > exp {
                print("❌ LASKO: LASKO auth request expired")
                clearAuthRequest()
                return nil
            }

            print("📥 LASKO: Retrieved LASKO auth request from App Groups: \(appName)")
            return LASKOAuthRequest(
                appName: appName,
                appId: appId,
                permissions: permissions,
                callbackURL: callbackURL,
                username: requestData["username"] as? String,
                nonce: requestData["nonce"] as? String
            )
        }
        
        // Fallback to file-based communication
        print("🔍 LASKO: Attempting to retrieve LASKO auth request from shared file...")
        if let requestData = readFromSharedFile(key: "lasko_auth_request") {
            print("📦 LASKO: Found request data in shared file")
            return parseAuthRequest(requestData)
        }
        
        print("❌ LASKO: No LASKO auth request found in App Groups or file")
        return nil
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
        
        // Write to App Groups
        if let defaults = sharedDefaults {
            defaults.set(responseData, forKey: "lasko_auth_response")
            defaults.synchronize()
            print("📤 LASKO: Auth response stored in App Groups for: \(session.tlsAddress)")
            
            // Debug: Check all keys in App Groups container after storing
            let allKeys = defaults.dictionaryRepresentation().keys
            print("🔍 LASKO: All keys in App Groups container after storing response: \(allKeys)")
            
            for key in allKeys {
                if let value = defaults.object(forKey: key) {
                    print("📊 LASKO: Key '\(key)' = \(value)")
                }
            }
        } else {
            print("❌ LASKO: Cannot store auth response - App Groups not accessible")
        }
        
        // ALSO write to shared file as fallback
        let fileSuccess = writeToSharedFile(key: "lasko_auth_response", data: responseData)
        if fileSuccess {
            print("📤 LASKO: Auth response also stored in shared file for: \(session.tlsAddress)")
        } else {
            print("⚠️ LASKO: Failed to store auth response in shared file")
        }
    }
    
    func getLASKOAuthResponse() -> LASKOAuthSession? {
        // First try App Groups
        if let responseData = sharedDefaults?.dictionary(forKey: "lasko_auth_response") {
            guard let tlsAddress = responseData["tlsAddress"] as? String,
                  let sessionToken = responseData["sessionToken"] as? String,
                  let signature = responseData["signature"] as? String,
                  let timestamp = responseData["timestamp"] as? Int64,
                  let expiresAt = responseData["expiresAt"] as? Int64,
                  let permissions = responseData["permissions"] as? [String] else {
                print("❌ LASKO: Invalid LASKO auth response data from App Groups")
                return nil
            }
            // TTL enforcement for responses
            let now = Int64(Date().timeIntervalSince1970)
            if now > expiresAt {
                print("❌ LASKO: LASKO auth response expired - clearing")
                clearAuthResponse()
                return nil
            }
            
            print("📥 LASKO: Retrieved LASKO auth response from App Groups for: \(tlsAddress.redactedAddress())")
            return LASKOAuthSession(
                tlsAddress: tlsAddress,
                sessionToken: sessionToken,
                signature: signature,
                timestamp: timestamp,
                expiresAt: expiresAt,
                permissions: permissions
            )
        }
        
        // Fallback to file-based communication
        if let responseData = readFromSharedFile(key: "lasko_auth_response") {
            guard let tlsAddress = responseData["tlsAddress"] as? String,
                  let sessionToken = responseData["sessionToken"] as? String,
                  let signature = responseData["signature"] as? String,
                  let timestamp = responseData["timestamp"] as? Int64,
                  let expiresAt = responseData["expiresAt"] as? Int64,
                  let permissions = responseData["permissions"] as? [String] else {
                print("❌ LASKO: Invalid LASKO auth response data from file")
                return nil
            }
            
            print("📥 LASKO: Retrieved LASKO auth response from shared file for: \(tlsAddress)")
            return LASKOAuthSession(
                tlsAddress: tlsAddress,
                sessionToken: sessionToken,
                signature: signature,
                timestamp: timestamp,
                expiresAt: expiresAt,
                permissions: permissions
            )
        }
        
        return nil
    }
    
    // MARK: - Cleanup
    
    func clearAuthRequest() {
        sharedDefaults?.removeObject(forKey: "lasko_auth_request")
        print("🧹 LASKO: Cleared LASKO auth request")
    }
    
    func clearAuthResponse() {
        sharedDefaults?.removeObject(forKey: "lasko_auth_response")
        print("🧹 LASKO: Cleared LASKO auth response")
    }
    
    func clearAll() {
        clearAuthRequest()
        clearAuthResponse()
        print("🧹 LASKO: Cleared all App Groups data")
    }
    
    // MARK: - File-Based Communication
    
    private func writeToSharedFile(key: String, data: [String: Any]) -> Bool {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ LASKO: Cannot access documents directory")
            return false
        }
        
        let sharedDirectory = documentsPath.appendingPathComponent("Shared")
        
        // Create shared directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: sharedDirectory, withIntermediateDirectories: true)
        } catch {
            print("❌ LASKO: Failed to create shared directory: \(error)")
            return false
        }
        
        let fileURL = sharedDirectory.appendingPathComponent("\(key).json")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            try jsonData.write(to: fileURL)
            print("📁 LASKO: Successfully wrote \(key) to shared file: \(fileURL.path)")
            return true
        } catch {
            print("❌ LASKO: Failed to write \(key) to shared file: \(error)")
            return false
        }
    }
    
    private func readFromSharedFile(key: String) -> [String: Any]? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ LASKO: Cannot access documents directory")
            return nil
        }
        
        let sharedDirectory = documentsPath.appendingPathComponent("Shared")
        let fileURL = sharedDirectory.appendingPathComponent("\(key).json")
        
        do {
            let jsonData = try Data(contentsOf: fileURL)
            let data = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            print("📁 LASKO: Successfully read \(key) from shared file: \(fileURL.path)")
            return data
        } catch {
            print("❌ LASKO: Failed to read \(key) from shared file: \(error)")
            return nil
        }
    }
    
    private func parseAuthRequest(_ data: [String: Any]) -> LASKOAuthRequest? {
        guard let appName = data["appName"] as? String,
              let appId = data["appId"] as? String,
              let permissions = data["permissions"] as? [String],
              let callbackURL = data["callbackURL"] as? String else {
            print("❌ LASKO: Invalid auth request data from file")
            return nil
        }
        guard isAllowedCallback(callbackURL) else { return nil }
        let now = Date().timeIntervalSince1970
        if let exp = data["expiresAt"] as? Double, now > exp { clearAuthRequest(); return nil }

        return LASKOAuthRequest(
            appName: appName,
            appId: appId,
            permissions: permissions,
            callbackURL: callbackURL,
            username: data["username"] as? String,
            nonce: data["nonce"] as? String
        )
    }

    private func isAllowedCallback(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme?.lowercased() == "lasko" && url.host?.lowercased() == "auth" && url.path == "/callback"
    }
    
    // MARK: - Status Checking
    
    func hasPendingAuthRequest() -> Bool {
        // Check both App Groups and file
        let appGroupsHasRequest = sharedDefaults?.object(forKey: "lasko_auth_request") != nil
        let fileHasRequest = readFromSharedFile(key: "lasko_auth_request") != nil
        
        print("🔍 LASKO: Auth request check - App Groups: \(appGroupsHasRequest), File: \(fileHasRequest)")
        return appGroupsHasRequest || fileHasRequest
    }
    
    func hasAuthResponse() -> Bool {
        // Check both App Groups and file
        let appGroupsHasResponse = sharedDefaults?.object(forKey: "lasko_auth_response") != nil
        let fileHasResponse = readFromSharedFile(key: "lasko_auth_response") != nil
        
        print("🔍 LASKO: Auth response check - App Groups: \(appGroupsHasResponse), File: \(fileHasResponse)")
        return appGroupsHasResponse || fileHasResponse
    }
} 