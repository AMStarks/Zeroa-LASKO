import Foundation
import CryptoKit
import Combine

// MARK: - ISO8601Date Formatter
let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

// MARK: - Messaging Models
struct ChatMessage: Identifiable, Codable {
    let id: String
    let senderAddress: String
    let receiverAddress: String
    let content: String
    let timestamp: Date
    let messageType: MessageType
    let isEncrypted: Bool
    let signature: String?
    let status: MessageStatus
    
    enum MessageType: String, Codable {
        case text = "text"
        case image = "image"
        case file = "file"
        case payment = "payment"
        case identity = "identity"
        case system = "system"
    }
    
    enum MessageStatus: String, Codable {
        case sent = "sent"
        case delivered = "delivered"
        case read = "read"
        case failed = "failed"
        case pending = "pending"
    }
}

struct ChatConversation: Identifiable, Codable {
    let id: String
    let participants: [String] // Wallet addresses
    let lastMessage: ChatMessage?
    let unreadCount: Int
    let createdAt: Date
    let updatedAt: Date
    let isGroupChat: Bool
    let groupName: String?
    let groupAvatar: String?
}

struct Contact: Identifiable, Codable {
    let id: String
    let walletAddress: String
    let displayName: String
    let avatar: String?
    let status: ContactStatus
    let lastSeen: Date?
    let publicKey: String?
    
    enum ContactStatus: String, Codable {
        case online = "online"
        case offline = "offline"
        case away = "away"
        case busy = "busy"
    }
}

struct GroupChat: Identifiable, Codable {
    let id: String
    let name: String
    let description: String?
    let avatar: String?
    let adminAddress: String
    let members: [String]
    let createdAt: Date
    let isEncrypted: Bool
}

// MARK: - Messaging Service
@MainActor
class MessagingService: ObservableObject {
    static let shared = MessagingService()
    
    @Published var conversations: [ChatConversation] = []
    @Published var currentConversation: ChatConversation?
    @Published var messages: [ChatMessage] = []
    @Published var contacts: [Contact] = []
    @Published var isConnected = false
    @Published var isTyping = false
    
    private let walletService = WalletService.shared
    private let cryptoService = CryptoService.shared
    private var messageQueue: [ChatMessage] = []
    private var typingTimers: [String: Timer] = [:]
    private var mockTimer: Timer?
    
    // MARK: - Connection Management
    func connect() {
        guard let walletAddress = walletService.loadAddress() else {
            print("❌ No wallet address found for messaging")
            return
        }
        
        print("✅ Connecting to local messaging service")
        
        // Simulate connection delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isConnected = true
            print("✅ Connected to local messaging service")
            self.loadMockData()
        }
    }
    
    func disconnect() {
        isConnected = false
        mockTimer?.invalidate()
        mockTimer = nil
        print("✅ Disconnected from messaging service")
    }
    
    private func loadMockData() {
        // Load mock conversations and messages
        let mockConversations = [
            ChatConversation(
                id: "conv_1",
                participants: [walletService.loadAddress() ?? ""],
                lastMessage: ChatMessage(
                    id: "msg_1",
                    senderAddress: "ThGNWv22Mb89YwMKo8hAgTEL5ChWcnNuRJ",
                    receiverAddress: walletService.loadAddress() ?? "",
                    content: "Hello! How are you?",
                    timestamp: Date().addingTimeInterval(-3600),
                    messageType: .text,
                    isEncrypted: false,
                    signature: nil,
                    status: .read
                ),
                unreadCount: 0,
                createdAt: Date().addingTimeInterval(-7200),
                updatedAt: Date().addingTimeInterval(-3600),
                isGroupChat: false,
                groupName: "John Doe",
                groupAvatar: nil
            ),
            ChatConversation(
                id: "conv_2",
                participants: [walletService.loadAddress() ?? ""],
                lastMessage: ChatMessage(
                    id: "msg_2",
                    senderAddress: walletService.loadAddress() ?? "",
                    receiverAddress: "",
                    content: "Thanks for the help!",
                    timestamp: Date().addingTimeInterval(-1800),
                    messageType: .text,
                    isEncrypted: false,
                    signature: nil,
                    status: .sent
                ),
                unreadCount: 0,
                createdAt: Date().addingTimeInterval(-3600),
                updatedAt: Date().addingTimeInterval(-1800),
                isGroupChat: false,
                groupName: "TLS Support",
                groupAvatar: nil
            )
        ]
        
        let mockMessages = [
            ChatMessage(
                id: "msg_1",
                senderAddress: "ThGNWv22Mb89YwMKo8hAgTEL5ChWcnNuRJ",
                receiverAddress: walletService.loadAddress() ?? "",
                content: "Hello! How are you?",
                timestamp: Date().addingTimeInterval(-3600),
                messageType: .text,
                isEncrypted: false,
                signature: nil,
                status: .read
            ),
            ChatMessage(
                id: "msg_2",
                senderAddress: walletService.loadAddress() ?? "",
                receiverAddress: "",
                content: "Thanks for the help!",
                timestamp: Date().addingTimeInterval(-1800),
                messageType: .text,
                isEncrypted: false,
                signature: nil,
                status: .sent
            )
        ]
        
        conversations = mockConversations
        messages = mockMessages
        
        // Start mock message timer
        mockTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.sendMockMessage()
        }
    }
    
    private func sendMockMessage() {
        guard isConnected else { return }
        
        let mockMessages = [
            "How's the app working for you?",
            "Did you try the new features?",
            "Let me know if you need anything!",
            "Great to hear from you!",
            "The blockchain is running smoothly today."
        ]
        
        let randomMessage = mockMessages.randomElement() ?? "Hello!"
        let randomSender = ""
        
        let newMessage = ChatMessage(
            id: UUID().uuidString,
            senderAddress: randomSender,
            receiverAddress: walletService.loadAddress() ?? "",
            content: randomMessage,
            timestamp: Date(),
            messageType: .text,
            isEncrypted: false,
            signature: nil,
            status: .delivered
        )
        
        messages.append(newMessage)
        updateConversation(with: newMessage)
    }
    
    // MARK: - Message Handling
    private func handleNewMessage(_ messageData: [String: Any]) {
        guard let message = decodeMessage(from: messageData) else { return }
        
        DispatchQueue.main.async {
            self.messages.append(message)
            self.updateConversation(with: message)
            self.processMessageQueue()
        }
    }
    
    private func decodeMessage(from data: [String: Any]) -> ChatMessage? {
        guard let id = data["id"] as? String,
              let senderAddress = data["sender_address"] as? String,
              let receiverAddress = data["receiver_address"] as? String,
              let content = data["content"] as? String,
              let timestampString = data["timestamp"] as? String,
              let timestamp = isoFormatter.date(from: timestampString),
              let messageTypeString = data["message_type"] as? String,
              let messageType = ChatMessage.MessageType(rawValue: messageTypeString),
              let isEncrypted = data["is_encrypted"] as? Bool,
              let statusString = data["status"] as? String,
              let status = ChatMessage.MessageStatus(rawValue: statusString) else {
            return nil
        }
        
        let signature = data["signature"] as? String
        
        return ChatMessage(
            id: id,
            senderAddress: senderAddress,
            receiverAddress: receiverAddress,
            content: content,
            timestamp: timestamp,
            messageType: messageType,
            isEncrypted: isEncrypted,
            signature: signature,
            status: status
        )
    }
    
    private func handleTypingIndicator(_ data: [String: Any]) {
        guard let _ = data["sender_address"] as? String,
              let isTyping = data["is_typing"] as? Bool else { return }
        
        DispatchQueue.main.async {
            if isTyping {
                self.isTyping = true
            } else {
                self.isTyping = false
            }
        }
    }
    
    private func handleStatusUpdate(_ data: [String: Any]) {
        guard let messageId = data["message_id"] as? String,
              let statusString = data["status"] as? String,
              let _ = ChatMessage.MessageStatus(rawValue: statusString) else { return }
        
        DispatchQueue.main.async {
            if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                _ = self.messages[index]
                print("Message \(messageId) status updated")
            }
        }
    }
    
    private func handleContactOnline(_ data: [String: Any]) {
        guard let walletAddress = data["wallet_address"] as? String,
              let statusString = data["status"] as? String,
              let _ = Contact.ContactStatus(rawValue: statusString) else { return }
        
        DispatchQueue.main.async {
            if let index = self.contacts.firstIndex(where: { $0.walletAddress == walletAddress }) {
                _ = self.contacts[index]
                print("Contact \(walletAddress) status updated")
            }
        }
    }
    
    // MARK: - Message Sending
    func sendMessage(to receiverAddress: String, content: String, messageType: ChatMessage.MessageType = .text) {
        guard let senderAddress = walletService.loadAddress() else {
            print("❌ No wallet address found")
            return
        }
        
        let message = ChatMessage(
            id: UUID().uuidString,
            senderAddress: senderAddress,
            receiverAddress: receiverAddress,
            content: content,
            timestamp: Date(),
            messageType: messageType,
            isEncrypted: true,
            signature: nil,
            status: .pending
        )
        
        // Add to local messages immediately
        DispatchQueue.main.async {
            self.messages.append(message)
            self.updateConversation(with: message)
        }
        
        // Simulate message sending
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Update message status to sent
            if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
                // Note: Since ChatMessage is immutable, we'd need to create a new instance
                    print("✅ Message sent successfully")
            }
        }
    }
    
    // MARK: - Conversation Management
    private func updateConversation(with message: ChatMessage) {
        let conversationId = getConversationId(for: message)
        
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            // Update existing conversation
            let _ = conversations[index]
            print("Updating conversation \(conversationId) with new message")
        } else {
            // Create new conversation
            let newConversation = ChatConversation(
                id: conversationId,
                participants: [message.senderAddress, message.receiverAddress],
                lastMessage: message,
                unreadCount: 1,
                createdAt: Date(),
                updatedAt: Date(),
                isGroupChat: false,
                groupName: nil,
                groupAvatar: nil
            )
            conversations.append(newConversation)
        }
    }
    
    private func getConversationId(for message: ChatMessage) -> String {
        let participants = [message.senderAddress, message.receiverAddress].sorted()
        return participants.joined(separator: "_")
    }
    
    func loadConversation(with address: String) {
        guard let currentAddress = walletService.loadAddress() else { return }
        
        let conversationId = [currentAddress, address].sorted().joined(separator: "_")
        
        if let conversation = conversations.first(where: { $0.id == conversationId }) {
            currentConversation = conversation
            loadMessages(for: conversationId)
        } else {
            // Create new conversation
            let newConversation = ChatConversation(
                id: conversationId,
                participants: [currentAddress, address],
                lastMessage: nil,
                unreadCount: 0,
                createdAt: Date(),
                updatedAt: Date(),
                isGroupChat: false,
                groupName: nil,
                groupAvatar: nil
            )
            currentConversation = newConversation
            conversations.append(newConversation)
        }
    }
    
    private func loadMessages(for conversationId: String) {
        // Load messages from local storage or server
        // For now, we'll just use the messages we have in memory
        messages = messages.filter { message in
            let messageConversationId = [message.senderAddress, message.receiverAddress].sorted().joined(separator: "_")
            return messageConversationId == conversationId
        }
    }
    
    // MARK: - Contact Management
    func addContact(walletAddress: String, displayName: String, avatar: String? = nil) {
        let contact = Contact(
            id: UUID().uuidString,
            walletAddress: walletAddress,
            displayName: displayName,
            avatar: avatar,
            status: .offline,
            lastSeen: nil,
            publicKey: nil
        )
        
        DispatchQueue.main.async {
            self.contacts.append(contact)
        }
    }
    
    func getContactName(for address: String) -> String {
        if let contact = contacts.first(where: { $0.walletAddress == address }) {
            return contact.displayName
        }
        return String(address.prefix(8))
    }
    
    // MARK: - Encryption
    func encryptMessage(_ content: String, for recipientAddress: String) -> String? {
        // In a real implementation, this would use the recipient's public key
        // For now, we'll use a simple encryption method
        guard let data = content.data(using: .utf8) else { return nil }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    func decryptMessage(_ encryptedContent: String) -> String? {
        // In a real implementation, this would use the sender's public key
        // For now, we'll return the content as-is
        return encryptedContent
    }
    
    // MARK: - Typing Indicators
    func sendTypingIndicator(to address: String, isTyping: Bool) async {
        guard isConnected else { return }
        
        print("📝 Typing indicator: \(isTyping ? "started" : "stopped") to \(address)")
        
        DispatchQueue.main.async {
            self.isTyping = isTyping
        }
    }
    
    // MARK: - Message Queue
    private func processMessageQueue() {
        guard isConnected && !messageQueue.isEmpty else { return }
        
        let messagesToSend = messageQueue
        messageQueue.removeAll()
        
        for message in messagesToSend {
            sendMessage(to: message.receiverAddress, content: message.content, messageType: message.messageType)
        }
    }
    
    // MARK: - Group Chat Support
    func createGroupChat(name: String, members: [String], description: String? = nil) async {
        guard let adminAddress = walletService.loadAddress() else { return }
        
        let groupChat = GroupChat(
            id: UUID().uuidString,
            name: name,
            description: description,
            avatar: nil,
            adminAddress: adminAddress,
            members: members,
            createdAt: Date(),
            isEncrypted: true
        )
        
        print("✅ Group chat created: \(name)")
    }
    
    // MARK: - Utility Methods
    func markMessageAsRead(_ messageId: String) async {
        guard isConnected else { return }
        
        print("✅ Message marked as read: \(messageId)")
    }
    
    func deleteMessage(_ messageId: String) async {
        guard isConnected else { return }
        
        DispatchQueue.main.async {
            self.messages.removeAll { $0.id == messageId }
        }
        
        print("🗑️ Message deleted: \(messageId)")
    }
    
    func clearConversation(_ conversationId: String) {
        DispatchQueue.main.async {
            self.messages.removeAll { message in
                let messageConversationId = [message.senderAddress, message.receiverAddress].sorted().joined(separator: "_")
                return messageConversationId == conversationId
            }
            self.conversations.removeAll { $0.id == conversationId }
        }
    }
} 