import Foundation

final class HaloAPIService {
    static let shared = HaloAPIService()

    private let baseURL = URL(string: "https://api.telestai.io/api")!
    private let appGroups = AppGroupsService.shared

    struct Challenge: Decodable {
        let nonce: String
        let ttlSeconds: Int
    }

    struct VerifyResponse: Decodable {
        let token: String
        let exp: Int64
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
        defaults.synchronize()
    }

    func requestChallenge(address: String, bundleId: String) async throws -> Challenge {
        var comps = URLComponents(url: baseURL.appendingPathComponent("halo/challenge"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "address", value: address),
            URLQueryItem(name: "bundleId", value: bundleId)
        ]
        let url = comps.url!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
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

    func verify(address: String, bundleId: String, nonce: String, signature: String) async throws -> VerifyResponse {
        let url = baseURL.appendingPathComponent("halo/verify")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "address": address,
            "bundleId": bundleId,
            "nonce": nonce,
            "signature": signature
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(VerifyResponse.self, from: data)
    }
}


