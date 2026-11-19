import Foundation

@MainActor
final class HaloService: ObservableObject {
    static let shared = HaloService()

    @Published var isAuthenticated: Bool = false
    @Published var tokenExp: Int64 = 0

    private let api = HaloAPIService.shared
    private let wallet = WalletService.shared

    func ensureToken(bundleId: String = "com.zeroa.wallet") async {
        guard let address = wallet.loadAddress() else { print("❌ HaloService: No TLS address loaded, abort ensureToken"); return }
        let now = Int64(Date().timeIntervalSince1970)
        if let (tok, exp) = api.storedToken(), exp - now > 60 {
            self.isAuthenticated = true
            self.tokenExp = exp
            print("🔐 HaloService: Using stored token exp=\(exp)")
            return
        }
        do {
            print("🔎 HaloService: Requesting challenge for address=\(address) bundleId=\(bundleId)")
            let challenge = try await api.requestChallenge(address: address, bundleId: bundleId)
            print("🧩 HaloService: Received challenge nonce=\(challenge.nonce) ttl=\(challenge.ttlSeconds)s")
            // Build canonical per server: LASKO|<nonce>|<ttlSeconds>|<bundleId>
            let canonical = "LASKO|\(challenge.nonce)|\(challenge.ttlSeconds)|\(bundleId)"
            // Sign canonical using secp256k1 and return Base64-encoded r||s
            guard let signature = CryptoService.shared.signMessageBase64(canonical, keychain: wallet.keychain) else {
                throw URLError(.cannotCreateFile)
            }
            let pubHex = CryptoService.shared.getCompressedPublicKeyHex(keychain: wallet.keychain) ?? ""
            print("✍️ HaloService: Verifying signature (len=\(signature.count)) for canonical…")
            let verified = try await api.verify(address: address, bundleId: bundleId, nonce: challenge.nonce, signature: signature, pubkeyCompressedHex: pubHex)
            let expSeconds: Int64 = {
                if let e = verified.exp { return e }
                if let secs = verified.expiresIn { return Int64(Date().timeIntervalSince1970) + Int64(secs) }
                return Int64(Date().timeIntervalSince1970) + 600
            }()
            api.storeToken(verified.token, exp: expSeconds)
            self.isAuthenticated = true
            self.tokenExp = expSeconds
            print("✅ HaloService: Token stored exp=\(verified.exp)")
        } catch {
            self.isAuthenticated = false
            print("❌ Halo auth failed: \(error)")
        }
    }

    /// Proves ownership with a Halo challenge, then deletes that address's Halo account data.
    func deleteAccount(bundleId: String = "com.zeroa.wallet") async throws {
        guard let address = wallet.loadAddress(), !address.isEmpty else {
            throw HaloAccountDeletionError.missingWallet
        }
        let challenge = try await api.requestChallenge(address: address, bundleId: bundleId)
        let canonical = "LASKO|\(challenge.nonce)|\(challenge.ttlSeconds)|\(bundleId)"
        guard let signature = CryptoService.shared.signMessageBase64(canonical, keychain: wallet.keychain),
              let pubHex = CryptoService.shared.getCompressedPublicKeyHex(keychain: wallet.keychain),
              !pubHex.isEmpty else {
            throw HaloAccountDeletionError.signatureFailed
        }
        try await api.deleteAccount(
            address: address,
            bundleId: bundleId,
            nonce: challenge.nonce,
            signature: signature,
            pubkeyCompressedHex: pubHex
        )
        api.clearStoredToken()
        self.isAuthenticated = false
        self.tokenExp = 0
    }
}


