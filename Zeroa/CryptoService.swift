import Foundation
import CryptoKit
#if canImport(P256K)
import P256K
typealias Secp = P256K
#elseif canImport(secp256k1)
import secp256k1
typealias Secp = secp256k1
#endif

final class CryptoService {
    static let shared = CryptoService()

    // Sign a message using a 32-byte secp256k1 private key stored in Keychain under "wallet_private_key"
    // Returns Base58-encoded 64-byte compact (r||s) signature to match server expectations
    func signMessageWithStoredPrivateKey(_ message: String, keychain: KeychainService) -> String? {
        guard let messageData = message.data(using: .utf8) else { return nil }
        guard let privHex = keychain.read(key: "wallet_private_key") else {
            print("❌ CryptoService: Missing wallet_private_key in Keychain")
            return nil
        }
        guard let privKeyData = Data(hexString: privHex), privKeyData.count == 32 else {
            print("❌ CryptoService: Invalid private key format/length")
            return nil
        }
        do {
            let digest = SHA256.hash(data: messageData)
            let privateKey = try Secp.Signing.PrivateKey(dataRepresentation: privKeyData)
            let signature = try privateKey.signature(for: digest)
            let sigRaw = signature.dataRepresentation // 64 bytes r||s
            let sigB58 = Base58.encode(sigRaw)
            return sigB58
        } catch {
            print("❌ CryptoService: Signing error: \(error)")
            return nil
        }
    }

    // Back-compat: legacy call sites pass a mnemonic but we now sign from stored key
    func signMessage(_ message: String, mnemonic: String) -> String? {
        return signMessageWithStoredPrivateKey(message, keychain: KeychainService.shared)
    }

    // Returns Base64-encoded 64-byte compact (r||s) signature for server verify
    func signMessageBase64(_ message: String, keychain: KeychainService) -> String? {
        guard let messageData = message.data(using: .utf8) else { return nil }
        guard let privHex = keychain.read(key: "wallet_private_key") else { return nil }
        guard let privKeyData = Data(hexString: privHex), privKeyData.count == 32 else { return nil }
        do {
            let digest = SHA256.hash(data: messageData)
            let privateKey = try Secp.Signing.PrivateKey(dataRepresentation: privKeyData)
            let signature = try privateKey.signature(for: digest)
            let sigRaw = signature.dataRepresentation // 64 bytes r||s
            return sigRaw.base64EncodedString()
        } catch {
            return nil
        }
    }

    // Returns compressed public key hex (33 bytes) derived from stored private key
    func getCompressedPublicKeyHex(keychain: KeychainService) -> String? {
        guard let privHex = keychain.read(key: "wallet_private_key") else { return nil }
        guard let privKeyData = Data(hexString: privHex), privKeyData.count == 32 else { return nil }
        do {
            let privateKey = try Secp.Signing.PrivateKey(dataRepresentation: privKeyData)
            // Prefer compressed representation when available; fallback to dataRepresentation
            #if canImport(P256K)
            let pubData = privateKey.publicKey.dataRepresentation
            #else
            let pubData = privateKey.publicKey.dataRepresentation
            #endif
            return pubData.map { String(format: "%02x", $0) }.joined()
        } catch {
            return nil
        }
    }
}

// MARK: - Utilities
private let base58Alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

enum Base58 {
    static func encode(_ data: Data) -> String {
        if data.isEmpty { return "" }
        var bytes = [UInt8](data)
        var zeros = 0
        var i = 0
        while i < bytes.count && bytes[i] == 0 { zeros += 1; i += 1 }
        var encoded: [UInt8] = []
        var input = Array(bytes[i...])
        while input.count > 0 {
            var remainder = 0
            var newInput: [UInt8] = []
            newInput.reserveCapacity(input.count)
            for b in input {
                let acc = Int(b) + remainder * 256
                let div = acc / 58
                remainder = acc % 58
                if !(newInput.isEmpty && div == 0) {
                    newInput.append(UInt8(div))
                }
            }
            encoded.append(UInt8(base58Alphabet[remainder].utf8.first!))
            input = newInput
        }
        // Add leading zeros
        while zeros > 0 { encoded.append(UInt8(base58Alphabet[0].utf8.first!)); zeros -= 1 }
        encoded.reverse()
        return String(bytes: encoded, encoding: .utf8) ?? ""
    }
}

extension Data {
    init?(hexString: String) {
        let hex = hexString.dropFirst(hexString.hasPrefix("0x") ? 2 : 0)
        guard hex.count % 2 == 0 else { return nil }
        var newData = Data(capacity: hex.count/2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard nextIndex <= hex.endIndex else { return nil }
            let byteString = hex[index..<nextIndex]
            guard let num = UInt8(byteString, radix: 16) else { return nil }
            newData.append(num)
            index = nextIndex
        }
        self = newData
    }
}
