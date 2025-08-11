import Foundation

// P2P Contact structure
struct P2PContact: Identifiable, Codable {
    let id: String
    let name: String
    let address: String
    let publicKey: String
    let lastSeen: Date
    let isOnline: Bool
    
    init(id: String = UUID().uuidString, name: String, address: String, publicKey: String, lastSeen: Date = Date(), isOnline: Bool = false) {
        self.id = id
        self.name = name
        self.address = address
        self.publicKey = publicKey
        self.lastSeen = lastSeen
        self.isOnline = isOnline
    }
}

// P2P Conversation structure
struct P2PConversation: Identifiable, Codable {
    let id: String
    let contactId: String
    let contactName: String
    let lastMessage: String
    let timestamp: Date
    let unreadCount: Int
    let participantAddress: String
    
    init(id: String = UUID().uuidString, contactId: String, contactName: String, lastMessage: String, timestamp: Date = Date(), unreadCount: Int = 0) {
        self.id = id
        self.contactId = contactId
        self.contactName = contactName
        self.lastMessage = lastMessage
        self.timestamp = timestamp
        self.unreadCount = unreadCount
        self.participantAddress = contactId
    }
}

// P2P Message structure
struct P2PMessage: Identifiable, Codable {
    let id: String
    let senderId: String
    let receiverId: String
    let content: String
    let timestamp: Date
    let messageType: P2PMessageType
    let isRead: Bool
    
    enum P2PMessageType: String, Codable {
        case text
        case image
        case file
        case payment
    }
    
    init(id: String = UUID().uuidString, senderId: String, receiverId: String, content: String, timestamp: Date = Date(), messageType: P2PMessageType = .text, isRead: Bool = false) {
        self.id = id
        self.senderId = senderId
        self.receiverId = receiverId
        self.content = content
        self.timestamp = timestamp
        self.messageType = messageType
        self.isRead = isRead
    }
} 