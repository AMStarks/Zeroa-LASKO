import Foundation
import Combine
import Network

class TLSLayer2MessagingService: ObservableObject {
    static let shared = TLSLayer2MessagingService()
    
    @Published var contacts: [P2PContact] = []
    @Published var conversations: [P2PConversation] = []
    @Published var messages: [P2PMessage] = []
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    
    private var cancellables = Set<AnyCancellable>()
    private let walletService = WalletService.shared
    private var webSocketTask: URLSessionWebSocketTask?
    private let serverURL = "http://43.224.35.187:8000"
    private let wsURL = "ws://43.224.35.187:8000/ws"
    
    init() {
        setupMockData() // Keep some initial data for UI
        startConnection()
    }
    
    private func setupMockData() {
        // Initial mock data for UI testing
        contacts = [
            P2PContact(name: "Alice", address: "alice123", publicKey: "pubkey1", isOnline: true),
            P2PContact(name: "Bob", address: "bob456", publicKey: "pubkey2", isOnline: false),
            P2PContact(name: "Charlie", address: "charlie789", publicKey: "pubkey3", isOnline: true)
        ]
        
        conversations = [
            P2PConversation(contactId: "alice123", contactName: "Alice", lastMessage: "Hey, how are you?", unreadCount: 2),
            P2PConversation(contactId: "bob456", contactName: "Bob", lastMessage: "Thanks for the help!", unreadCount: 0),
            P2PConversation(contactId: "charlie789", contactName: "Charlie", lastMessage: "See you later!", unreadCount: 1)
        ]
        
        messages = [
            P2PMessage(senderId: "alice123", receiverId: "self", content: "Hey, how are you?"),
            P2PMessage(senderId: "self", receiverId: "alice123", content: "I'm good, thanks!"),
            P2PMessage(senderId: "bob456", receiverId: "self", content: "Thanks for the help!"),
            P2PMessage(senderId: "charlie789", receiverId: "self", content: "See you later!")
        ]
    }
    
    func startConnection() {
        // Connect to WebSocket for real-time messaging
        connectWebSocket()
        
        // Register with server
        registerPeer()
        
        // Discover peers
        discoverPeers()
        
        // Load message history
        loadMessageHistory()
    }
    
    private func connectWebSocket() {
        guard let url = URL(string: "\(wsURL)/\(walletService.loadAddress() ?? "")") else {
            print("❌ Invalid WebSocket URL")
            return
        }
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receiveMessage()
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatus = "Connected"
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleWebSocketMessage(message)
                self?.receiveMessage() // Continue receiving
            case .failure(let error):
                print("❌ WebSocket receive error: \(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self?.connectWebSocket() // Reconnect
                }
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            if let data = text.data(using: .utf8),
               let messageData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                if messageData["type"] as? String == "message",
                   let data = messageData["data"] as? [String: Any] {
                    
                    let message = P2PMessage(
                        senderId: data["sender_address"] as? String ?? "",
                        receiverId: data["receiver_address"] as? String ?? "",
                        content: data["encrypted_content"] as? String ?? "",
                        messageType: P2PMessage.P2PMessageType(rawValue: data["message_type"] as? String ?? "text") ?? .text
                    )
                    
                    DispatchQueue.main.async {
                        self.messages.append(message)
                        self.updateConversation(for: message)
                    }
                }
            }
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                handleWebSocketMessage(.string(text))
            }
        @unknown default:
            break
        }
    }
    
    private func registerPeer() {
        guard let address = walletService.loadAddress() else { return }
        
        let peerData: [String: Any] = [
            "address": address,
            "public_key": address, // Using address as public key for now
            "connection_info": [:],
            "is_online": true
        ]
        
        sendAPIRequest(endpoint: "/api/v1/peer/register", method: "POST", data: peerData) { [weak self] result in
            switch result {
            case .success(let response):
                print("✅ Peer registered: \(response)")
            case .failure(let error):
                print("❌ Peer registration failed: \(error)")
            }
        }
    }
    
    private func discoverPeers() {
        guard let address = walletService.loadAddress() else { return }
        
        sendAPIRequest(endpoint: "/api/v1/peers/discover?address=\(address)", method: "GET") { [weak self] result in
            switch result {
            case .success(let response):
                if let data = response as? [String: Any],
                   let peersData = data["peers"] as? [[String: Any]] {
                    
                    DispatchQueue.main.async {
                        self?.contacts = peersData.compactMap { peerData in
                            guard let address = peerData["address"] as? String,
                                  let publicKey = peerData["public_key"] as? String else { return nil }
                            
                            return P2PContact(
                                name: address, // Use address as name for now
                                address: address,
                                publicKey: publicKey,
                                isOnline: peerData["is_online"] as? Bool ?? false
                            )
                        }
                    }
                }
            case .failure(let error):
                print("❌ Peer discovery failed: \(error)")
            }
        }
    }
    
    private func loadMessageHistory() {
        guard let address = walletService.loadAddress() else { return }
        
        sendAPIRequest(endpoint: "/api/v1/messages/\(address)", method: "GET") { [weak self] result in
            switch result {
            case .success(let response):
                if let data = response as? [String: Any],
                   let messagesData = data["messages"] as? [[String: Any]] {
                    
                    DispatchQueue.main.async {
                        self?.messages = messagesData.compactMap { messageData in
                            guard let senderId = messageData["sender_address"] as? String,
                                  let receiverId = messageData["receiver_address"] as? String,
                                  let content = messageData["encrypted_content"] as? String else { return nil }
                            
                            return P2PMessage(
                                senderId: senderId,
                                receiverId: receiverId,
                                content: content,
                                messageType: P2PMessage.P2PMessageType(rawValue: messageData["message_type"] as? String ?? "text") ?? .text
                            )
                        }
                        
                        // Update conversations based on messages
                        self?.updateConversationsFromMessages()
                    }
                }
            case .failure(let error):
                print("❌ Message history load failed: \(error)")
            }
        }
    }
    
    private func sendAPIRequest(endpoint: String, method: String, data: [String: Any]? = nil, completion: @escaping (Result<Any, Error>) -> Void) {
        guard let url = URL(string: "\(serverURL)\(endpoint)") else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let data = data {
            request.httpBody = try? JSONSerialization.data(withJSONObject: data)
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data)
                completion(.success(json))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func sendMessage(to contactId: String, content: String) {
        guard let senderAddress = walletService.loadAddress() else { return }
        
        let messageData: [String: Any] = [
            "sender_address": senderAddress,
            "receiver_address": contactId,
            "encrypted_content": content, // In production, this should be encrypted
            "message_type": "text",
            "signature": "dummy_signature" // In production, this should be a real signature
        ]
        
        sendAPIRequest(endpoint: "/api/v1/message/relay", method: "POST", data: messageData) { [weak self] result in
            switch result {
            case .success(let response):
                print("✅ Message sent: \(response)")
                
                // Add message locally
                let message = P2PMessage(senderId: senderAddress, receiverId: contactId, content: content)
                DispatchQueue.main.async {
                    self?.messages.append(message)
                    self?.updateConversation(for: message)
                }
                
            case .failure(let error):
                print("❌ Message send failed: \(error)")
            }
        }
    }
    
    private func updateConversation(for message: P2PMessage) {
        let contactId = message.senderId == walletService.loadAddress() ? message.receiverId : message.senderId
        
        if let index = conversations.firstIndex(where: { $0.contactId == contactId }) {
            conversations[index] = P2PConversation(
                contactId: contactId,
                contactName: conversations[index].contactName,
                lastMessage: message.content,
                unreadCount: message.senderId != walletService.loadAddress() ? conversations[index].unreadCount + 1 : 0
            )
        } else {
            // Create new conversation
            let contact = contacts.first { $0.address == contactId }
            let conversation = P2PConversation(
                contactId: contactId,
                contactName: contact?.name ?? contactId,
                lastMessage: message.content,
                unreadCount: message.senderId != walletService.loadAddress() ? 1 : 0
            )
            conversations.append(conversation)
        }
    }
    
    private func updateConversationsFromMessages() {
        var conversationMap: [String: P2PConversation] = [:]
        
        for message in messages {
            let contactId = message.senderId == walletService.loadAddress() ? message.receiverId : message.senderId
            
            if let existing = conversationMap[contactId] {
                conversationMap[contactId] = P2PConversation(
                    contactId: contactId,
                    contactName: existing.contactName,
                    lastMessage: message.content,
                    unreadCount: message.senderId != walletService.loadAddress() ? existing.unreadCount + 1 : existing.unreadCount
                )
            } else {
                let contact = contacts.first { $0.address == contactId }
                conversationMap[contactId] = P2PConversation(
                    contactId: contactId,
                    contactName: contact?.name ?? contactId,
                    lastMessage: message.content,
                    unreadCount: message.senderId != walletService.loadAddress() ? 1 : 0
                )
            }
        }
        
        conversations = Array(conversationMap.values)
    }
    
    func getMessages(for contactId: String) -> [P2PMessage] {
        return messages.filter { message in
            (message.senderId == contactId && message.receiverId == walletService.loadAddress()) ||
            (message.senderId == walletService.loadAddress() && message.receiverId == contactId)
        }.sorted { $0.timestamp < $1.timestamp }
    }
    
    func addContact(name: String, address: String, publicKey: String) {
        let contact = P2PContact(name: name, address: address, publicKey: publicKey)
        contacts.append(contact)
    }
    
    func getContacts() -> [P2PContact] {
        return contacts
    }
    
    func sendP2PMessage(to contactId: String, content: String) async -> Bool {
        sendMessage(to: contactId, content: content)
        return true
    }
    
    func removeContact(contactId: String) {
        contacts.removeAll { $0.id == contactId }
        conversations.removeAll { $0.contactId == contactId }
        messages.removeAll { $0.senderId == contactId || $0.receiverId == contactId }
    }
    
    func markAsRead(contactId: String) {
        // Mark messages as read
        for i in 0..<messages.count {
            if messages[i].senderId == contactId && messages[i].receiverId == walletService.loadAddress() {
                messages[i] = P2PMessage(
                    id: messages[i].id,
                    senderId: messages[i].senderId,
                    receiverId: messages[i].receiverId,
                    content: messages[i].content,
                    timestamp: messages[i].timestamp,
                    messageType: messages[i].messageType,
                    isRead: true
                )
            }
        }
        
        // Update conversation unread count
        if let index = conversations.firstIndex(where: { $0.contactId == contactId }) {
            conversations[index] = P2PConversation(
                contactId: contactId,
                contactName: conversations[index].contactName,
                lastMessage: conversations[index].lastMessage,
                unreadCount: 0
            )
        }
    }
    
    deinit {
        webSocketTask?.cancel()
    }
}
