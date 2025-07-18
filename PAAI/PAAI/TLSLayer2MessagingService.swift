import Foundation
import CryptoKit
import Network

// MARK: - Enhanced P2P Messaging Service
class TLSLayer2MessagingService: ObservableObject {
    static let shared = TLSLayer2MessagingService()
    
    @Published var conversations: [P2PConversation] = []
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    
    private var p2pConnections: [String: P2PConnection] = [:]
    private let tlsService = TLSBlockchainService.shared
    private let cryptoService = CryptoService.shared
    private let keychain = KeychainService.shared
    
    // P2P Network Components
    private var listener: NWListener?
    private var browser: NWBrowser?
    private let serviceType = "_paai-messaging._tcp"
    
    init() {
        setupP2PNetwork()
    }
    
    // MARK: - P2P Network Setup
    private func setupP2PNetwork() {
        // Check if we're in simulator (which has P2P limitations)
        #if targetEnvironment(simulator)
        DispatchQueue.main.async {
            self.connectionStatus = "Simulator Mode - P2P Limited"
            self.isConnected = false
        }
        return
        #endif
        
        // Create P2P listener for incoming connections
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        
        do {
            listener = try NWListener(using: parameters)
            listener?.service = NWListener.Service(name: "PAAI-Messaging", type: serviceType)
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.connectionStatus = "Connected"
                        self?.isConnected = true
                    case .failed(let error):
                        print("❌ P2P Listener failed: \(error)")
                        self?.connectionStatus = "Failed: \(error.localizedDescription)"
                        self?.isConnected = false
                    case .cancelled:
                        self?.connectionStatus = "Disconnected"
                        self?.isConnected = false
                    default:
                        break
                    }
                }
            }
            
            listener?.start(queue: .main)
            
            // Start browsing for other P2P peers
            startPeerDiscovery()
            
        } catch {
            print("❌ Failed to setup P2P listener: \(error)")
            DispatchQueue.main.async {
                self.connectionStatus = "Setup Failed: \(error.localizedDescription)"
                self.isConnected = false
            }
        }
    }
    
    private func startPeerDiscovery() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        do {
            browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)
            browser?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.handleDiscoveredPeers()
                    case .failed(let error):
                        print("❌ P2P Browser failed: \(error)")
                        self?.connectionStatus = "Discovery Failed: \(error.localizedDescription)"
                    default:
                        break
                    }
                }
            }
            browser?.start(queue: .main)
        } catch {
            print("❌ Failed to start peer discovery: \(error)")
            DispatchQueue.main.async {
                self.connectionStatus = "Discovery Failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func handleDiscoveredPeers() {
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            print("🔍 Discovered \(results.count) P2P peers")
            for result in results {
                self?.connectToPeer(result.endpoint)
            }
        }
    }
    
    private func connectToPeer(_ endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    print("✅ P2P connection established")
                    self?.handleP2PConnection(connection)
                case .failed(let error):
                    print("❌ P2P connection failed: \(error)")
                case .cancelled:
                    print("🔌 P2P connection cancelled")
                default:
                    break
                }
            }
        }
        
        connection.start(queue: .main)
    }
    
    // MARK: - P2P Message Handling
    private func handleP2PConnection(_ connection: NWConnection) {
        connection.receiveMessage { [weak self] content, context, isComplete, error in
            if let error = error {
                print("❌ P2P receive error: \(error)")
                return
            }
            
            guard let content = content else { return }
            
            if let message = try? JSONDecoder().decode(P2PMessage.self, from: content) {
                self?.processIncomingP2PMessage(message)
            }
        }
    }
    
    private func processIncomingP2PMessage(_ message: P2PMessage) {
        // Verify message signature using blockchain
        Task {
            if await verifyMessageSignature(message) {
                // Decrypt message content
                if let decryptedContent = decryptMessage(message.encryptedContent, from: message.senderAddress) {
                    await MainActor.run {
                        self.addMessageToConversation(
                            senderAddress: message.senderAddress,
                            content: decryptedContent,
                            timestamp: message.timestamp,
                            messageType: message.messageType
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Message Sending
    func sendP2PMessage(to address: String, content: String) async -> Bool {
        guard let myAddress = keychain.read(key: "wallet_address") else { return false }
        
        // Get recipient's public key from blockchain
        guard let recipientPublicKey = await getPublicKeyFromBlockchain(address) else {
            return false
        }
        
        // Encrypt message with recipient's public key
        guard let encryptedContent = encryptMessage(content, for: recipientPublicKey) else {
            return false
        }
        
        // Create P2P message
        var message = P2PMessage(
            senderAddress: myAddress,
            recipientAddress: address,
            encryptedContent: encryptedContent,
            timestamp: Date(),
            messageType: .p2p
        )
        
        // Sign message with private key
        guard let signature = await signMessage(message) else { return false }
        message.signature = signature
        
        // Send via P2P connection
        if let connection = p2pConnections[address] {
            return await sendMessageViaP2P(message, through: connection)
        } else {
            // Fallback to blockchain if P2P not available
            return await sendMessageViaBlockchain(message)
        }
    }
    
    private func sendMessageViaP2P(_ message: P2PMessage, through connection: P2PConnection) async -> Bool {
        guard let messageData = try? JSONEncoder().encode(message) else { return false }
        
        return await withCheckedContinuation { continuation in
            connection.send(content: messageData) { error in
                if let error = error {
                    print("❌ P2P send error: \(error)")
                }
                continuation.resume(returning: error == nil)
            }
        }
    }
    
    private func sendMessageViaBlockchain(_ message: P2PMessage) async -> Bool {
        // Fallback to blockchain messaging
        let response = await tlsService.sendMessageTransaction(
            toAddress: message.recipientAddress,
            encryptedMessage: message.encryptedContent,
            messageType: "p2p_fallback"
        )
        return response.success
    }
    
    // MARK: - Blockchain Integration
    private func getPublicKeyFromBlockchain(_ address: String) async -> String? {
        // Mock implementation - in real app, get from TLS blockchain
        return "mock_public_key_for_\(address)"
    }
    
    private func verifyMessageSignature(_ message: P2PMessage) async -> Bool {
        // Mock implementation - in real app, verify using blockchain
        return message.signature != nil && !message.signature!.isEmpty
    }
    
    private func signMessage(_ message: P2PMessage) async -> String? {
        guard let privateKey = keychain.read(key: "wallet_private_key") else { return nil }
        
        let messageData = "\(message.senderAddress)\(message.recipientAddress)\(message.encryptedContent)\(message.timestamp.timeIntervalSince1970)"
        
        return cryptoService.signMessage(messageData, mnemonic: privateKey)
    }
    
    // MARK: - Encryption/Decryption
    private func encryptMessage(_ content: String, for publicKey: String) -> String? {
        guard let contentData = content.data(using: .utf8) else { return nil }
        
        // Generate ephemeral key for this message
        let ephemeralKey = P256.KeyAgreement.PrivateKey()
        let ephemeralPublicKey = ephemeralKey.publicKey
        
        // Derive shared secret
        guard let recipientPublicKey = try? P256.KeyAgreement.PublicKey(rawRepresentation: Data(hex: publicKey) ?? Data()) else {
            return nil
        }
        
        guard let sharedSecret = try? ephemeralKey.sharedSecretFromKeyAgreement(with: recipientPublicKey) else {
            return nil
        }
        
        // Derive encryption key
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: "PAAI-Messaging".data(using: .utf8)!,
            sharedInfo: Data(),
            outputByteCount: 32
        )
        
        // Encrypt content
        let sealedBox = try? AES.GCM.seal(contentData, using: symmetricKey)
        guard let encryptedData = sealedBox?.combined else { return nil }
        
        // Combine ephemeral public key and encrypted data
        let combined = ephemeralPublicKey.rawRepresentation + encryptedData
        return combined.base64EncodedString()
    }
    
    private func decryptMessage(_ encryptedContent: String, from senderAddress: String) -> String? {
        guard let encryptedData = Data(base64Encoded: encryptedContent) else { return nil }
        guard let privateKey = keychain.read(key: "wallet_private_key") else { return nil }
        
        // Extract ephemeral public key and encrypted data
        let ephemeralKeySize = 65 // P256 public key size
        guard encryptedData.count > ephemeralKeySize else { return nil }
        
        let ephemeralPublicKeyData = encryptedData.prefix(ephemeralKeySize)
        let encryptedMessageData = encryptedData.dropFirst(ephemeralKeySize)
        
        guard let ephemeralPublicKey = try? P256.KeyAgreement.PublicKey(rawRepresentation: ephemeralPublicKeyData),
              let myPrivateKey = try? P256.KeyAgreement.PrivateKey(rawRepresentation: Data(hex: privateKey) ?? Data()) else {
            return nil
        }
        
        // Derive shared secret
        guard let sharedSecret = try? myPrivateKey.sharedSecretFromKeyAgreement(with: ephemeralPublicKey) else {
            return nil
        }
        
        // Derive decryption key
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: "PAAI-Messaging".data(using: .utf8)!,
            sharedInfo: Data(),
            outputByteCount: 32
        )
        
        // Decrypt content
        guard let sealedBox = try? AES.GCM.SealedBox(combined: encryptedMessageData),
              let decryptedData = try? AES.GCM.open(sealedBox, using: symmetricKey) else {
            return nil
        }
        
        return String(data: decryptedData, encoding: .utf8)
    }
    
    // MARK: - Conversation Management
    private func addMessageToConversation(senderAddress: String, content: String, timestamp: Date, messageType: P2PMessage.MessageType) {
        if let index = conversations.firstIndex(where: { $0.participantAddress == senderAddress }) {
            conversations[index].messages.append(
                P2PMessage(
                    senderAddress: senderAddress,
                    recipientAddress: "",
                    encryptedContent: content,
                    timestamp: timestamp,
                    messageType: messageType
                )
            )
        } else {
            // Create new conversation
            let newConversation = P2PConversation(
                participantAddress: senderAddress,
                messages: [
                    P2PMessage(
                        senderAddress: senderAddress,
                        recipientAddress: "",
                        encryptedContent: content,
                        timestamp: timestamp,
                        messageType: messageType
                    )
                ]
            )
            conversations.append(newConversation)
        }
    }
    
    // MARK: - Contact Management
    func addContact(address: String, name: String) async -> Bool {
        // Verify address exists on blockchain
        guard await verifyAddressOnBlockchain(address) else { return false }
        
        // Get public key from blockchain
        guard let publicKey = await getPublicKeyFromBlockchain(address) else { return false }
        
        // Store contact locally
        let contact = P2PContact(address: address, name: name, publicKey: publicKey)
        saveContact(contact)
        
        return true
    }
    
    private func verifyAddressOnBlockchain(_ address: String) async -> Bool {
        // Mock implementation - in real app, verify on TLS blockchain
        return address.hasPrefix("TLS") && address.count > 10
    }
    
    private func saveContact(_ contact: P2PContact) {
        // Save to UserDefaults for now, could be moved to secure storage
        var contacts = UserDefaults.standard.array(forKey: "p2p_contacts") as? [[String: String]] ?? []
        
        let contactData: [String: String] = [
            "address": contact.address,
            "name": contact.name,
            "publicKey": contact.publicKey
        ]
        
        if !contacts.contains(where: { $0["address"] == contact.address }) {
            contacts.append(contactData)
            UserDefaults.standard.set(contacts, forKey: "p2p_contacts")
        }
    }
    
    func getContacts() -> [P2PContact] {
        let contactsData = UserDefaults.standard.array(forKey: "p2p_contacts") as? [[String: String]] ?? []
        
        return contactsData.compactMap { data in
            guard let address = data["address"],
                  let name = data["name"],
                  let publicKey = data["publicKey"] else { return nil }
            
            return P2PContact(address: address, name: name, publicKey: publicKey)
        }
    }
}

// MARK: - Data Models
struct P2PConversation: Identifiable {
    var id = UUID()
    let participantAddress: String
    var messages: [P2PMessage]
    var lastMessage: String {
        messages.last?.encryptedContent ?? ""
    }
    var lastMessageTime: Date {
        messages.last?.timestamp ?? Date()
    }
}

struct P2PMessage: Identifiable, Codable {
    var id = UUID()
    let senderAddress: String
    let recipientAddress: String
    let encryptedContent: String
    let timestamp: Date
    let messageType: MessageType
    var signature: String?
    
    enum MessageType: String, Codable {
        case p2p = "p2p"
        case blockchain = "blockchain"
    }
}

struct P2PContact: Identifiable {
    let id = UUID()
    let address: String
    let name: String
    let publicKey: String
}

class P2PConnection {
    let connection: NWConnection
    let address: String
    
    init(connection: NWConnection, address: String) {
        self.connection = connection
        self.address = address
    }
    
    func send(content: Data, completion: @escaping (NWError?) -> Void) {
        connection.send(content: content, completion: .contentProcessed { error in
            completion(error)
        })
    }
}

// MARK: - Extensions
extension Data {
    init?(hex: String) {
        let chars = Array(hex)
        let bytes = stride(from: 0, to: chars.count, by: 2).map {
            String(chars[$0..<Swift.min($0 + 2, chars.count)])
        }
        let data = bytes.compactMap { UInt8($0, radix: 16) }
        self.init(data)
    }
    
    var hex: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
} 