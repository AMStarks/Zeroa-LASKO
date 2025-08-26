import Foundation

@MainActor
final class HaloService: ObservableObject {
    static let shared = HaloService()

    @Published var isAuthenticated: Bool = false
    @Published var tokenExp: Int64 = 0

    private let api = HaloAPIService.shared
    private let wallet = WalletService.shared

    func ensureToken(bundleId: String = "com.telestai.Zeroa") async {
        guard let address = wallet.loadAddress() else { return }
        let now = Int64(Date().timeIntervalSince1970)
        if let (tok, exp) = api.storedToken(), exp - now > 60 {
            self.isAuthenticated = true
            self.tokenExp = exp
            return
        }
        do {
            let challenge = try await api.requestChallenge(address: address, bundleId: bundleId)
            // Sign nonce using WalletService -> CryptoService (placeholder until real secp256k1 added)
            let signature = wallet.signMessage(challenge.nonce) ?? ""
            let verified = try await api.verify(address: address, bundleId: bundleId, nonce: challenge.nonce, signature: signature)
            api.storeToken(verified.token, exp: verified.exp)
            self.isAuthenticated = true
            self.tokenExp = verified.exp
        } catch {
            self.isAuthenticated = false
            print("❌ Halo auth failed: \(error)")
        }
    }
}


