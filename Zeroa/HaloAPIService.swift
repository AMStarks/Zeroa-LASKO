import Foundation

final class HaloAPIService {
    static let shared = HaloAPIService()

    private let baseURL = URL(string: "https://halo.telestai.io/api")!
    private let appGroups = AppGroupsService.shared

    struct Challenge: Decodable {
        let nonce: String
        let ttlSeconds: Int
    }

    struct VerifyResponse: Decodable {
        let success: Bool?
        let token: String
        let exp: Int64?
        let expiresIn: Int?
    }

    func storedToken() -> (token: String, exp: Int64)? {
        guard let defaults = appGroups.sharedDefaults else { return nil }
        if let token = defaults.string(forKey: "halo_access_token"),
           let exp = defaults.object(forKey: "halo_token_expires_at") as? Int64 {
            return (token, exp)
        }
        return nil
    }

    func storeToken(_ token: String, exp: Int64) {
        guard let defaults = appGroups.sharedDefaults else { return }
        defaults.set(token, forKey: "halo_access_token")
        defaults.set(exp, forKey: "halo_token_expires_at")
        // Back-compat alias some codepaths use
        defaults.set(token, forKey: "haloAccessToken")
        let nowMs = Int(Date().timeIntervalSince1970 * 1000)
        defaults.set(nowMs, forKey: "halo_token_refreshed_at")
        defaults.synchronize()
    }

    func requestChallenge(address: String, bundleId: String) async throws -> Challenge {
        // Try /halo/challenge first, then fallback to /auth/challenge for older servers
        func doRequest(_ path: String) async throws -> (Data, URLResponse) {
            var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
            comps.queryItems = [
                URLQueryItem(name: "address", value: address),
                URLQueryItem(name: "bundleId", value: bundleId)
            ]
            var req = URLRequest(url: comps.url!)
            req.httpMethod = "GET"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue(bundleId, forHTTPHeaderField: "X-Bundle-Id")
            return try await URLSession.shared.data(for: req)
        }

        var (data, response) = try await doRequest("halo/challenge")
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            (data, response) = try await doRequest("auth/challenge")
        }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ HaloAPIService.challenge HTTP \(http.statusCode): \(body)")
            throw URLError(.badServerResponse)
        }
        // Support both {nonce, ttlSeconds} and {data:{nonce, ttlSeconds}}
        if let direct = try? JSONDecoder().decode(Challenge.self, from: data) {
            return direct
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataObj = obj["data"] as? [String: Any],
           let nonce = dataObj["nonce"] as? String,
           let ttl = dataObj["ttlSeconds"] as? Int {
            return Challenge(nonce: nonce, ttlSeconds: ttl)
        }
        throw URLError(.cannotParseResponse)
    }

    func verify(address: String, bundleId: String, nonce: String, signature: String, pubkeyCompressedHex: String) async throws -> VerifyResponse {
        // Try /halo/verify first, then fallback to /auth/verify for older servers
        func doVerify(_ path: String) async throws -> (Data, URLResponse) {
            let url = baseURL.appendingPathComponent(path)
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(bundleId, forHTTPHeaderField: "X-Bundle-Id")
            let body: [String: String] = [
                "address": address,
                "bundleId": bundleId,
                "nonce": nonce,
                "signature": signature,
                "pubkey": pubkeyCompressedHex
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            return try await URLSession.shared.data(for: req)
        }
        var (data, response) = try await doVerify("halo/verify")
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            (data, response) = try await doVerify("auth/verify")
        }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ HaloAPIService.verify HTTP \(http.statusCode): \(body)")
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(VerifyResponse.self, from: data)
    }
}


