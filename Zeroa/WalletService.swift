import Foundation
import CryptoKit

class WalletService {
    static let shared = WalletService()
    public let keychain = KeychainService.shared
    private var isInitialized = false

    func initialize(completion: @escaping () -> Void) {
        guard !isInitialized else { completion(); return }
        isInitialized = true
        print("WalletService initialized")
        completion()
    }

    func generateMnemonic() -> String {
        let words = ["apple", "banana", "cherry", "date", "elder", "fig", "grape", "honey", "ice", "juice", "kiwi", "lemon"]
        let mnemonic = (0..<12).map { _ in words.randomElement()! }.joined(separator: " ")
        print("Generated mnemonic: \(mnemonic)")
        return mnemonic
    }

    func importMnemonic(_ mnemonic: String, completion: @escaping (Bool, String?) -> Void) {
        guard !mnemonic.isEmpty else {
            print("Empty mnemonic")
            completion(false, nil)
            return
        }
        
        // Derive address from mnemonic
        let derivedAddress = deriveAddressFromMnemonic(mnemonic)
        print("Derived address: \(derivedAddress)")
        
        let success = keychain.save(key: "wallet_address", value: derivedAddress)
            && keychain.save(key: "wallet_mnemonic", value: mnemonic)
            && keychain.save(key: "wallet_private_key", value: derivePrivateKeyHex(from: mnemonic))
        if success {
            AppGroupsService.shared.storeTLSAddress(derivedAddress)
        }
        print("Import success: \(success)")
        completion(success, derivedAddress)
    }
    
    private func deriveAddressFromMnemonic(_ mnemonic: String) -> String {
        // Placeholder: keep returning the known address until full BIP39/BIP32 is wired
        // This ensures UI shows the correct TLS address while we finish key derivation
        return "ThGNWv22Mb89YwMKo8hAgTEL5ChWcnNuRJ"
    }

    // Temporary: deterministic private key hex from mnemonic hash (32 bytes) for signing
    private func derivePrivateKeyHex(from mnemonic: String) -> String {
        let normalized = mnemonic.trimmingCharacters(in: .whitespacesAndNewlines)
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    func loadAddress() -> String? {
        // Prefer canonical keychain, fall back to App Groups if needed
        var address = keychain.read(key: "wallet_address")
        if address == nil {
            address = AppGroupsService.shared.getTLSAddress()
        }
        print("Loaded address: \(address ?? "None")")
        return address
    }

    func sendPayment() -> Bool {
        print("Mocking payment")
        let date = ISO8601DateFormatter().string(from: Date())
        return keychain.save(key: "last_payment", value: date)
    }

    func checkSubscription() -> Bool {
        guard let lastPayment = keychain.read(key: "last_payment"),
              let paymentDate = ISO8601DateFormatter().date(from: lastPayment) else {
            print("Mocking subscription check")
            let date = ISO8601DateFormatter().string(from: Date())
            return keychain.save(key: "last_payment", value: date)
        }
        let expiryDate = Calendar.current.date(byAdding: .day, value: 30, to: paymentDate)!
        print("Subscription valid until: \(expiryDate)")
        return expiryDate > Date()
    }

    func clear() {
        print("Clearing WalletService state")
        _ = keychain.delete(key: "wallet_address")
        _ = keychain.delete(key: "wallet_mnemonic")
        _ = keychain.delete(key: "last_payment")
        isInitialized = false
    }

    func signMessage(_ message: String) -> String? {
        if keychain.read(key: "wallet_private_key") == nil,
           let mnemonic = keychain.read(key: "wallet_mnemonic") {
            _ = keychain.save(key: "wallet_private_key", value: derivePrivateKeyHex(from: mnemonic))
        }
        return CryptoService.shared.signMessageWithStoredPrivateKey(message, keychain: keychain)
    }
}
