import SwiftUI

@main
struct PAAIApp: App {
    @StateObject private var authManager = AuthManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
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
