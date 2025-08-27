import SwiftUI
import UIKit

@main
struct ZeroaApp: App {
    @StateObject private var authManager = AuthManager()
    @State private var showingLASKOAuth = false
    @State private var laskoAuthRequest: LASKOAuthRequest?
    @StateObject private var authService = LASKOAuthService()
    @State private var laskoCheckTimer: Timer?
    @State private var didNotifyLASKO = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .onOpenURL { url in
                    handleLASKORequest(url)
                }
                .onAppear {
                    Task { await HaloService.shared.ensureToken() }
                    // Seed Flux address if not present (from user-provided address)
                    if AppGroupsService.shared.getFluxAddress() == nil {
                        AppGroupsService.shared.storeFluxAddress("t1fBrjkEro8DUfQ3c7nPuF96qmz3C3MVDNL")
                    }
                    // Seed TLS address into App Groups if present but missing
                    if AppGroupsService.shared.getTLSAddress() == nil,
                       let tls = WalletService.shared.loadAddress() {
                        AppGroupsService.shared.storeTLSAddress(tls)
                    }
                    // Persist compressed public key once at startup for LASKO reuse
                    if AppGroupsService.shared.sharedDefaults?.string(forKey: "zeroa_pubkey_compressed_hex") == nil,
                       let pubHex = CryptoService.shared.getCompressedPublicKeyHex(keychain: WalletService.shared.keychain) {
                        AppGroupsService.shared.sharedDefaults?.set(pubHex, forKey: "zeroa_pubkey_compressed_hex")
                        AppGroupsService.shared.sharedDefaults?.synchronize()
                    }
                }
                // Headless mode: no sheet presentation
                .onChange(of: authManager.isAuthenticated) { isAuthed in
                    print("🔍 Auth state changed: isAuthenticated=\(isAuthed)")
                    if isAuthed, let pendingRequest = authService.checkForPendingAuthRequest() {
                        Task { await headlessApproveLASKO(request: pendingRequest) }
                    }
                }
                .onAppear {
                    checkForPendingLASKORequests()
                    startLASKORequestTimer()
                    // Do not reset didNotifyLASKO on appear to avoid re-opening LASKO on stale responses
                    // If a stored request is already present when coming to foreground for the first time, show immediately
                    if let pendingRequest = authService.checkForPendingAuthRequest() {
                        if authManager.isAuthenticated {
                            Task { await headlessApproveLASKO(request: pendingRequest) }
                            didNotifyLASKO = false
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task { await HaloService.shared.ensureToken() }
                    checkForPendingLASKORequests()
                    startLASKORequestTimer()
                    handleBackgroundHandshakes()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    stopLASKORequestTimer()
                }
        }
    }
    
    private func startLASKORequestTimer() {
        print("⏰ Starting LASKO request timer...")
        stopLASKORequestTimer() // Stop any existing timer
        
        // Add a timer to actively check for LASKO requests and background handshakes (token refresh, post-sign)
        laskoCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            checkForPendingLASKORequests()
            handleBackgroundHandshakes()
        }
        print("✅ LASKO request timer started (checking every 1 second)")
    }
    
    private func stopLASKORequestTimer() {
        print("⏰ Stopping LASKO request timer...")
        laskoCheckTimer?.invalidate()
        laskoCheckTimer = nil
        print("✅ LASKO request timer stopped")
    }
    
    private func checkForPendingLASKORequests() {
        print("🔍 Checking for pending LASKO auth requests...")
        
        // Check for pending auth request (App Groups only)
        if let pendingRequest = authService.checkForPendingAuthRequest() {
            print("📥 Found pending LASKO auth request: \(pendingRequest.appName)")
            print("📋 Request details: \(pendingRequest.permissions)")
            print("🔍 Current auth state: isAuthenticated=\(authManager.isAuthenticated)")
            
            // Headless: if logged in, sign and respond silently; otherwise do nothing
            if authManager.isAuthenticated {
                print("✅ Zeroa is logged in - performing headless approval")
                Task { await headlessApproveLASKO(request: pendingRequest) }
            } else {
                print("❌ Zeroa is not logged in - deferring headless approval until login")
            }
            return
        }
        
        // Check for completed auth response (App Groups only)
        if let authResponse = authService.getAuthResponseFromZeroa() {
            print("✅ Found completed LASKO auth response")
            print("📋 Response details: \(authResponse.tlsAddress) - \(authResponse.permissions)")
            // Headless: do not app-switch; simply leave response for LASKO to consume
            return
        }
        
        print("✅ No pending LASKO auth requests")
    }

    // MARK: - Background handshakes (post-sign + token refresh)
    private func handleBackgroundHandshakes() {
        // Token refresh request from LASKO
        if AppGroupsService.shared.hasTokenRefreshRequest() {
            Task {
                print("🔁 Zeroa: Received halo_token_refresh_request → ensuring token...")
                await HaloService.shared.ensureToken()
                print("✅ Zeroa: Token refresh attempt complete; marking halo_token_refreshed_at and clearing request")
                AppGroupsService.shared.markTokenRefreshed()
                AppGroupsService.shared.clearTokenRefreshRequest()
            }
        }
        // Post-sign request
        if let req = AppGroupsService.shared.getPostSignRequest() {
            guard authManager.isAuthenticated else { return }
            let contentHash = req["contentHashHex"] as? String ?? ""
            let timestampMs = (req["timestamp"] as? Int64) ?? Int64(Date().timeIntervalSince1970 * 1000)
            let userAddress = WalletService.shared.loadAddress() ?? ""
            let bundleId = Bundle.main.bundleIdentifier ?? ""
            let canonical = "LASKO_POST|\(contentHash)|\(timestampMs)|\(userAddress)|\(bundleId)|v1"
            if let sigB64 = CryptoService.shared.signMessageBase64(canonical, keychain: WalletService.shared.keychain),
               let pubHex = CryptoService.shared.getCompressedPublicKeyHex(keychain: WalletService.shared.keychain) {
                AppGroupsService.shared.storePostSignResponse(signatureBase64: sigB64, pubkeyCompressedHex: pubHex, timestampMs: timestampMs)
                AppGroupsService.shared.clearPostSignRequest()
            }
        }
    }
    
    private func headlessApproveLASKO(request: LASKOAuthRequest) async {
        do {
            print("✍️ Zeroa: Creating session and signature for LASKO headlessly…")
            let session = try await authService.createLASKOAuthSession(permissions: request.permissions)
            authService.sendAuthResponseToLASKO(session)
            print("✅ Zeroa: Auth response written to App Groups for LASKO")
        } catch {
            print("❌ Zeroa: Failed to create/send LASKO auth response: \(error)")
        }
    }
    
    private func handleLASKORequest(_ url: URL) {
        print("🔗 Received URL scheme request: \(url)")
        
        // Custom scheme only: zeroa://auth
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard url.scheme == "zeroa", url.host == "auth" else {
            print("❌ Invalid URL for LASKO request: \(url)")
            return
        }
        
        // Extract parameters
        let queryItems = components?.queryItems ?? []
        
        var requestData: [String: String] = [:]
        for item in queryItems {
            requestData[item.name] = item.value
        }
        
        // Extract LASKO's request
        let appName = requestData["app"] ?? "LASKO"
        let appId = requestData["appId"] ?? "com.telestai.LASKO"
        let permissions = requestData["permissions"]?.components(separatedBy: ",") ?? ["post", "read"]
        let callbackURL = requestData["callback"] ?? "lasko://auth/callback"
        let username = requestData["username"]
        
        print("📥 Processing LASKO request via URL scheme: \(appName)")
        
        // Create auth request object
        let authRequest = LASKOAuthRequest(
            appName: appName,
            appId: appId,
            permissions: permissions,
            callbackURL: callbackURL,
            username: username,
            nonce: requestData["nonce"]
        )
        
        // ALWAYS show manual approval - NEVER auto-process
        if authManager.isAuthenticated {
            print("✅ Zeroa is logged in - showing authentication UI")
            laskoAuthRequest = authRequest
            showingLASKOAuth = true
        } else {
            print("❌ Zeroa is not logged in - cannot authenticate LASKO")
        }
    }
}

// MARK: - Authentication Manager
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    init() {
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        print("🔍 Checking authentication status...")
        isLoading = true
        
        // Check if user has saved credentials
        if let savedAddress = WalletService.shared.loadAddress() {
            print("📋 Found saved address: \(savedAddress)")
            
            if let savedMnemonic = WalletService.shared.keychain.read(key: "wallet_mnemonic") {
                print("🔑 Found saved mnemonic in keychain")
                
                WalletService.shared.importMnemonic(savedMnemonic) { success, derivedAddress in
                    DispatchQueue.main.async {
                        print("🔍 Mnemonic import result: success=\(success), derivedAddress=\(derivedAddress ?? "nil")")
                        print("🔍 Address comparison: saved=\(savedAddress), derived=\(derivedAddress ?? "nil"), match=\(savedAddress == (derivedAddress ?? ""))")
                        
                        self.isAuthenticated = success && derivedAddress == savedAddress
                        print("✅ Authentication status set to: \(self.isAuthenticated)")
                        self.isLoading = false
                    }
                }
            } else {
                print("❌ No mnemonic found in keychain")
                DispatchQueue.main.async {
                    self.isAuthenticated = false
                    self.isLoading = false
                }
            }
        } else {
            print("❌ No saved address found")
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.isLoading = false
            }
        }
    }
    
    func signIn(address: String, mnemonic: String, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        
        WalletService.shared.importMnemonic(mnemonic) { success, derivedAddress in
            DispatchQueue.main.async {
                if success && derivedAddress == address {
                    self.isAuthenticated = true
                    completion(true, nil)
                } else {
                    completion(false, "Invalid address or mnemonic")
                }
                self.isLoading = false
            }
        }
    }
    
    func signUp(address: String, mnemonic: String, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        
        // For sign up, we'll use the provided mnemonic directly
        WalletService.shared.importMnemonic(mnemonic) { success, derivedAddress in
            DispatchQueue.main.async {
                if success && derivedAddress == address {
                    self.isAuthenticated = true
                    completion(true, nil)
                } else {
                    completion(false, "Invalid address or mnemonic")
                }
                self.isLoading = false
            }
        }
    }
    
    func signOut() {
        isAuthenticated = false
        // Clear saved credentials
        WalletService.shared.keychain.delete(key: "wallet_mnemonic")
        UserDefaults.standard.removeObject(forKey: "wallet_address")
    }
}
