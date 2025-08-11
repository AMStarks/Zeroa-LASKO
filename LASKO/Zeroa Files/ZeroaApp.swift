import SwiftUI

@main
struct ZeroaApp: App {
    @StateObject private var authManager = AuthManager()
    @State private var showingLASKOAuth = false
    @State private var laskoAuthRequest: LASKOAuthRequest?
    @StateObject private var authService = LASKOAuthService()
    @State private var laskoCheckTimer: Timer?
    
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
                    }
                }
                .onAppear {
                    checkForPendingLASKORequests()
                    startLASKORequestTimer()
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
        
        // Add a timer to actively check for LASKO requests
        laskoCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
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
        
        // First, check if there's already a completed auth response
        if let authResponse = authService.getAuthResponseFromZeroa() {
            print("✅ Found completed LASKO auth response")
            print("📋 Response details: \(authResponse.tlsAddress) - \(authResponse.permissions)")
            // Handle completed auth - maybe notify LASKO or clear response
            return
        }
        
        // Then check for pending auth request
        if let pendingRequest = authService.checkForPendingAuthRequest() {
            print("📥 Found pending LASKO auth request: \(pendingRequest.appName)")
            print("📋 Request details: \(pendingRequest.permissions)")
            
            // ADD THESE DEBUG LINES:
            print("🔧 About to set laskoAuthRequest...")
            laskoAuthRequest = pendingRequest
            print("🔧 About to set showingLASKOAuth = true...")
            showingLASKOAuth = true
            print("✅ showingLASKOAuth set to true")
            
            // Don't clear the request immediately - let the auth flow handle it
            // authService.clearAuthRequest()
        } else {
            print("❌ No LASKO auth request found in App Groups")
            print("✅ No pending LASKO auth requests")
        }
    }
    
    private func handleLASKORequest(_ url: URL) {
        // Parse the incoming request from LASKO
        guard url.scheme == "zeroa" && url.host == "auth" else { 
            print("Invalid URL scheme or host")
            return 
        }
        
        // Extract parameters
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        
        var requestData: [String: String] = [:]
        for item in queryItems {
            requestData[item.name] = item.value
        }
        
        // Extract LASKO's request
        let appName = requestData["app"] ?? ""
        let appId = requestData["appId"] ?? ""
        let permissions = requestData["permissions"]?.components(separatedBy: ",") ?? []
        let callbackURL = requestData["callback"] ?? ""
        
        // Create auth request object
        let authRequest = LASKOAuthRequest(
            appName: appName,
            appId: appId,
            permissions: permissions,
            callbackURL: callbackURL
        )
        
        // Show authentication UI
        laskoAuthRequest = authRequest
        showingLASKOAuth = true
        
        print("Received LASKO auth request: \(appName) requesting \(permissions)")
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
        isLoading = true
        
        // Check if user has saved credentials
        if let savedAddress = WalletService.shared.loadAddress(),
           let savedMnemonic = WalletService.shared.keychain.read(key: "wallet_mnemonic") {
            
            WalletService.shared.importMnemonic(savedMnemonic) { success, derivedAddress in
                DispatchQueue.main.async {
                    self.isAuthenticated = success && derivedAddress == savedAddress
                    self.isLoading = false
                }
            }
        } else {
            DispatchQueue.main.async {
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
