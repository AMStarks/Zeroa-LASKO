import Foundation
import CryptoKit

class CryptoService {
    static let shared = CryptoService()

    func signMessage(_ message: String, mnemonic: String) -> String? {
        guard let messageData = message.data(using: .utf8) else { return nil }
        let hash = SHA256.hash(data: messageData)
        let signature = "\(hash.description) (mocked with mnemonic: \(mnemonic))"
        print("Signed message: \(message), signature: \(signature)")
        return signature
    }
}
