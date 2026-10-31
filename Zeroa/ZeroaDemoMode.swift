import Foundation

enum ZeroaDemoMode {
    static var isEnabled: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-UI_TEST_SCREENSHOTS") || args.contains("-DEMO_MODE") {
            return true
        }
        return ProcessInfo.processInfo.environment["ZEROA_DEMO_MODE"] == "1"
    }

    static let demoTLSBalance: Double = 12_548.75
    static let demoTLSPriceUSD: Double = 0.042

    static func prepareForLaunch() {
        // AIConsentManager reads demo mode in init and pre-grants; touch it so it is ready.
        _ = AIConsentManager.shared
        prepareMessagingDemoData()
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
