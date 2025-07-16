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
        let address = "ThGNWv22Mb89YwMKo8hAgTEL5ChWcnNuRJ"
        print("Derived address: \(address)")
        let success = keychain.save(key: "wallet_address", value: address)
            && keychain.save(key: "wallet_mnemonic", value: mnemonic)
        print("Import success: \(success)")
        completion(success, address)
    }

    func loadAddress() -> String? {
        let address = keychain.read(key: "wallet_address")
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
        guard let mnemonic = keychain.read(key: "wallet_mnemonic") else {
            print("No mnemonic found for signing")
            return nil
        }
        return CryptoService.shared.signMessage(message, mnemonic: mnemonic)
    }
}
