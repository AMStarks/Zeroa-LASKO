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
                .sheet(isPresented: $showingLASKOAuth) {
                    if let request = laskoAuthRequest {
                        LASKOAuthRequestView(authRequest: request)
                    } else {
                        Text("No authentication request available")
                            .padding()
                    }
                }
                .onChange(of: showingLASKOAuth) { newValue in
                    print("🔍 showingLASKOAuth changed to: \(newValue)")
                    if newValue {
                        print("🔍 Sheet presentation triggered")
                        if let request = laskoAuthRequest {
                            print("🔍 Creating LASKOAuthRequestView with request: \(request.appName)")
                        } else {
                            print("❌ No auth request available for sheet")
                        }
                    }
                }
                .onAppear {
                    checkForPendingLASKORequests()
                    startLASKORequestTimer()
                    // Do not reset didNotifyLASKO on appear to avoid re-opening LASKO on stale responses
                    // If a stored request is already present when coming to foreground for the first time, show immediately
                    if let pendingRequest = authService.checkForPendingAuthRequest() {
                        if authManager.isAuthenticated {
                            DispatchQueue.main.async {
                                self.laskoAuthRequest = pendingRequest
                                self.showingLASKOAuth = true
                            }
                            didNotifyLASKO = false // only reset when we are actively presenting the approval flow
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    checkForPendingLASKORequests()
                    startLASKORequestTimer()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    stopLASKORequestTimer()
                }
        }
    }
    
    private func startLASKORequestTimer() {
        print("⏰ Starting LASKO request timer...")
        stopLASKORequestTimer() // Stop any existing timer
        
        // Add a timer to actively check for LASKO requests (backed off to reduce churn)
        laskoCheckTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
            checkForPendingLASKORequests()
        }
        print("✅ LASKO request timer started (checking every 2 seconds)")
    }
    
    private func stopLASKORequestTimer() {
        print("⏰ Stopping LASKO request timer...")
        laskoCheckTimer?.invalidate()
        laskoCheckTimer = nil
        print("✅ LASKO request timer stopped")
    }
    
    private func checkForPendingLASKORequests() {
        print("🔍 Checking for pending LASKO auth requests...")
        
        // Check for pending auth request
        if let pendingRequest = authService.checkForPendingAuthRequest() {
            print("📥 Found pending LASKO auth request: \(pendingRequest.appName)")
            print("📋 Request details: \(pendingRequest.permissions)")
            print("🔍 Current auth state: isAuthenticated=\(authManager.isAuthenticated)")
            
            // Check if Zeroa is logged in before showing auth UI
            if authManager.isAuthenticated {
                print("✅ Zeroa is logged in - showing authentication UI")
                
                // Set the request and show UI on main thread
                DispatchQueue.main.async {
                    print("🔧 Setting laskoAuthRequest to: \(pendingRequest.appName)")
                    self.laskoAuthRequest = pendingRequest
                    print("🔧 Setting showingLASKOAuth = true")
                    self.showingLASKOAuth = true
                    print("✅ UI state updated - authentication sheet should appear")
                }
            } else {
                print("❌ Zeroa is not logged in - cannot authenticate LASKO")
                print("🔧 Clearing auth request due to not being logged in")
                authService.clearAuthRequest()
            }
            return
        }
        
        // Check for completed auth response
        if let authResponse = authService.getAuthResponseFromZeroa() {
            print("✅ Found completed LASKO auth response")
            print("📋 Response details: \(authResponse.tlsAddress) - \(authResponse.permissions)")
            // Only trigger callback if we actually presented approval this session
            if showingLASKOAuth && !didNotifyLASKO {
                didNotifyLASKO = true
                let callback = URL(string: "lasko://auth/callback?status=approved")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if let url = callback {
                        print("🔗 Zeroa: Attempting to open LASKO callback URL: \(url)")
                        UIApplication.shared.open(url, options: [.universalLinksOnly: false]) { success in
                            print("🔗 Zeroa: Open LASKO callback URL result: \(success)")
                        }
                    }
                    // Consume response so we do not retrigger
                    AppGroupsService.shared.clearAuthResponse()
                }
            } else {
                // Stale response: consume silently and do nothing
                AppGroupsService.shared.clearAuthResponse()
            }
            return
        }
        
        print("✅ No pending LASKO auth requests")
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
