import Foundation

enum ZeroaDemoMode {
    static var isEnabled: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-UI_TEST_SCREENSHOTS") || args.contains("-DEMO_MODE") {
            return true
        }
        return ProcessInfo.processInfo.environment["ZEROA_DEMO_MODE"] == "1"
    }

    /// Deterministic Telestai-looking addresses for screenshots / demo.
    static let demoTLSAddress = "ThGNWv22Mb89YwMKo8hAgTEL5ChWcnNuRJ"
    /// Sample recipient used on the Send sheet in demo / screenshot mode.
    static let demoSendRecipientAddress = "TqR8mKp2vXn4sLw7yHd1cFb9jZa3eGu6Po"

    static let balances: [String: Double] = [
        "Telestai": 12_548.75,
        "Bitcoin": 0.0425,
        "Litecoin": 3.2,
        "Flux": 850,
        "Kaspa": 15_000,
        "USDT": 250,
        "USDC": 250
    ]

    static let pricesUSD: [String: Double] = [
        "Telestai": 0.042,
        "Bitcoin": 67_450.0,
        "Litecoin": 84.50,
        "Flux": 0.58,
        "Kaspa": 0.135,
        "USDT": 1.0,
        "USDC": 1.0
    ]

    static let priceChanges24h: [String: Double] = [
        "Telestai": 3.45,
        "Bitcoin": 1.82,
        "Litecoin": -0.95,
        "Flux": 4.10,
        "Kaspa": 6.25,
        "USDT": 0.01,
        "USDC": -0.01
    ]

    /// Seven sample points for the 7-day trend chart (oldest → newest).
    static let priceHistory: [String: [Double]] = [
        "Telestai": [0.038, 0.039, 0.040, 0.041, 0.0405, 0.0415, 0.042],
        "Bitcoin": [65_200, 65_800, 66_400, 66_100, 66_900, 67_200, 67_450],
        "Litecoin": [86.0, 85.5, 85.2, 85.8, 85.1, 84.8, 84.5],
        "Flux": [0.52, 0.53, 0.55, 0.54, 0.56, 0.57, 0.58],
        "Kaspa": [0.118, 0.122, 0.125, 0.128, 0.130, 0.133, 0.135],
        "USDT": [0.999, 1.001, 0.998, 1.002, 0.999, 1.001, 1.0],
        "USDC": [1.001, 0.999, 1.0, 1.001, 0.999, 1.0, 1.0]
    ]

    static func balance(for coin: String) -> Double { balances[coin] ?? 0 }
    static func priceUSD(for coin: String) -> Double { pricesUSD[coin] ?? 0 }
    static func change24h(for coin: String) -> Double { priceChanges24h[coin] ?? 0 }
    static func history(for coin: String) -> [Double] { priceHistory[coin] ?? [] }

    /// Backward-compatible aliases used by older call sites.
    static var demoTLSBalance: Double { balance(for: "Telestai") }
    static var demoTLSPriceUSD: Double { priceUSD(for: "Telestai") }

    static func prepareForLaunch() {
        if ZeroaFeatureFlags.aiFeaturesEnabled {
            _ = AIConsentManager.shared
        }
        if ZeroaFeatureFlags.switchboardEnabled {
            prepareMessagingDemoData()
        }
    }

    static func prepareMessagingDemoData() {
        let messaging = TLSLayer2MessagingService.shared
        if messaging.contacts.isEmpty {
            messaging.contacts = [
                P2PContact(name: "Alice", address: "alice123", publicKey: "pubkey1", isOnline: true),
                P2PContact(name: "Bob", address: "bob456", publicKey: "pubkey2", isOnline: false),
                P2PContact(name: "Carol", address: "carol789", publicKey: "pubkey3", isOnline: true)
            ]
        }
        if messaging.conversations.isEmpty {
            messaging.conversations = [
                P2PConversation(
                    contactId: "alice123",
                    contactName: "Alice",
                    lastMessage: "Can you send the invoice over Switchboard?",
                    unreadCount: 1
                ),
                P2PConversation(
                    contactId: "carol789",
                    contactName: "Carol",
                    lastMessage: "PowDEX quote looks good.",
                    unreadCount: 0
                )
            ]
        }
    }
}
