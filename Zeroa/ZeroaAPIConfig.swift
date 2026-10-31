import Foundation

/// Central network endpoints for Zeroa. Change `switchboardBaseURL` when DNS/TLS is ready.
enum ZeroaAPIConfig {
    /// Switchboard Layer-2 messaging origin (HTTPS). Placeholder until the server has a cert.
    /// Point DNS at the messaging host and terminate TLS on 443 (reverse proxy → app on :8000).
    static let switchboardBaseURL = URL(string: "https://api.telestai.io")!

    static var switchboardHTTPBase: String {
        switchboardBaseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// WSS base including `/ws` path; callers append `/{walletAddress}`.
    static var switchboardWebSocketBase: String {
        var components = URLComponents(url: switchboardBaseURL, resolvingAgainstBaseURL: false)!
        components.scheme = (components.scheme?.lowercased() == "https") ? "wss" : "ws"
        let root = (components.string ?? switchboardHTTPBase).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(root)/ws"
    }

    /// Display-only TURN host (not dialed by the current App Store binary WebRTC path).
    static var switchboardTURNDisplay: String {
        "\(switchboardBaseURL.host ?? "api.telestai.io"):3478"
    }

    static let xAIChatCompletionsURL = URL(string: "https://api.x.ai/v1/chat/completions")!

    /// Privacy policy linked from AI consent UI.
    static let privacyPolicyURL = URL(string: "https://docs.telestai.com/privacy")!
}
