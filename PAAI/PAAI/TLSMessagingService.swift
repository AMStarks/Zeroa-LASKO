import Foundation
import CryptoKit
import Combine

// MARK: - TLS Blockchain Messaging Models
struct TLSMessage: Codable, Identifiable {
    let id: String
    let senderAddress: String
    let receiverAddress: String
    let content: String
    let encryptedContent: String
    let timestamp: Date
    let messageType: TLSMessageType
    let signature: String
    let txid: String?
    let blockHeight: Int?
    let confirmations: Int
    
    enum TLSMessageType: String, Codable {
        case text = "text"
        case payment = "payment"
        case identity = "identity"
        case system = "system"
        case group = "group"
    }
}

struct TLSMessageTransaction: Codable {
    let txid: String
    let fromAddress: String
    let toAddress: String
    let amount: Double
    let fee: Double
    let messageData: String // Encrypted message data
    let timestamp: Date
    let blockHeight: Int
    let confirmations: Int
    let messageType: TLSMessage.TLSMessageType
}

struct TLSMessageRequest: Codable {
    let fromAddress: String
    let toAddress: String
    let encryptedContent: String
    let messageType: TLSMessage.TLSMessageType
    let fee: Double
    let signature: String
}

struct TLSMessageResponse: Codable {
    let success: Bool
    let txid: String?
    let error: String?
    let blockHeight: Int?
}

// MARK: - TLS Blockchain Messaging Service
@MainActor
class TLSMessagingService: ObservableObject {
    static let shared = TLSMessagingService()
    
    @Published var messages: [TLSMessage] = []
    @Published var conversations: [TLSConversation] = []
    @Published var isConnected = false
    @Published var lastBlockHeight: Int = 0
    @Published var pendingMessages: [TLSMessage] = []
    
    private let tlsService = TLSBlockchainService.shared
    private let walletService = WalletService.shared
    private let cryptoService = CryptoService.shared
    private var messageQueue: [TLSMessage] = []
    private var blockScanner: Timer?
    private var lastScannedBlock: Int = 0
    
    // MARK: - Connection Management
    func connect() async {
        guard let walletAddress = walletService.loadAddress() else {
            print("❌ No wallet address found for TLS messaging")
            return
        }
        
        print("🔗 Connecting to TLS blockchain for messaging...")
        
        // Check TLS blockchain connection
        let isConnected = await tlsService.checkConnection()
        if isConnected {
            self.isConnected = true
            print("✅ Connected to TLS blockchain")
            
            // Start block scanning for new messages
            await startBlockScanner()
            
            // Load existing messages from blockchain
            await loadMessagesFromBlockchain()
        } else {
            print("❌ Failed to connect to TLS blockchain")
            self.isConnected = false
        }
    }
    
    func disconnect() {
        isConnected = false
        blockScanner?.invalidate()
        blockScanner = nil
        print("🔌 Disconnected from TLS messaging service")
    }
    
    // MARK: - Blockchain Message Scanning
    private func startBlockScanner() async {
        // Get current block height
        guard let address = walletService.loadAddress() else { return }
        if let addressInfo = await tlsService.getAddressInfo(address: address) {
            lastScannedBlock = addressInfo.balance > 0 ? Int(addressInfo.balance) : 0 // Using balance as proxy for block height
        }
        
        // Scan for new messages every 10 seconds
        blockScanner = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task {
                await self?.scanForNewMessages()
            }
        }
    }
    
    private func scanForNewMessages() async {
        guard isConnected else { return }
        
        // Get recent transactions that might contain messages
        guard let address = walletService.loadAddress() else { return }
        let transactions = await tlsService.getTransactionHistory(address: address)
        
        for transaction in transactions {
            // Check if transaction contains message data
            if let messageData = extractMessageFromTransaction(transaction) {
                let message = TLSMessage(
                    id: transaction.txid,
                    senderAddress: transaction.from ?? "",
                    receiverAddress: transaction.to ?? "",
                    content: messageData.content,
                    encryptedContent: messageData.encryptedContent,
                    timestamp: Date(timeIntervalSince1970: TimeInterval(transaction.timestamp)),
                    messageType: messageData.messageType,
                    signature: messageData.signature,
                    txid: transaction.txid,
                    blockHeight: nil, // TLSTransaction doesn't have blockHeight
                    confirmations: transaction.confirmations
                )
                
                // Add to messages if not already present
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                    updateConversation(with: message)
                    print("📨 New message found in blockchain: \(message.content)")
                }
            }
        }
    }
    
    private func extractMessageFromTransaction(_ transaction: TLSTransaction) -> (content: String, encryptedContent: String, messageType: TLSMessage.TLSMessageType, signature: String)? {
        // In a real implementation, this would parse the transaction's message field
        // For now, we'll simulate message extraction from transaction data
        
        // Check if transaction has a message (simulated)
        let hasMessage = transaction.type == "send" && transaction.amount > 0
        
        if hasMessage {
            let content = "Message from transaction \(String(transaction.txid.prefix(8)))..."
            let encryptedContent = encryptMessage(content, for: transaction.to ?? "") ?? ""
            let messageType: TLSMessage.TLSMessageType = transaction.amount > 1.0 ? .payment : .text
            let signature = cryptoService.signMessage(content, mnemonic: walletService.keychain.read(key: "wallet_mnemonic") ?? "") ?? ""
            
            return (content: content, encryptedContent: encryptedContent, messageType: messageType, signature: signature)
        }
        
        return nil
    }
    
    // MARK: - Message Sending
    func sendMessage(to receiverAddress: String, content: String, messageType: TLSMessage.TLSMessageType = .text) async -> TLSMessageResponse {
        guard let senderAddress = walletService.loadAddress() else {
            return TLSMessageResponse(success: false, txid: nil, error: "No wallet address found", blockHeight: nil)
        }
        
        // Encrypt message for recipient
        guard let encryptedContent = encryptMessage(content, for: receiverAddress) else {
            return TLSMessageResponse(success: false, txid: nil, error: "Failed to encrypt message", blockHeight: nil)
        }
        
        // Sign the message
        guard let signature = cryptoService.signMessage(content, mnemonic: walletService.keychain.read(key: "wallet_mnemonic") ?? "") else {
            return TLSMessageResponse(success: false, txid: nil, error: "Failed to sign message", blockHeight: nil)
        }
        
        // Create message transaction
        let messageFee = 0.001 // Small fee for message transaction
        let messageAmount = messageType == .payment ? 0.1 : 0.0 // Payment messages include actual payment
        
        // Send transaction with message data
        let paymentResponse = await tlsService.sendPayment(
            toAddress: receiverAddress,
            amount: messageAmount,
            message: encryptedContent
        )
        
        if paymentResponse.success {
            // Create message object
            let message = TLSMessage(
                id: paymentResponse.txid ?? UUID().uuidString,
                senderAddress: senderAddress,
                receiverAddress: receiverAddress,
                content: content,
                encryptedContent: encryptedContent,
                timestamp: Date(),
                messageType: messageType,
                signature: signature,
                txid: paymentResponse.txid,
                blockHeight: nil, // Will be updated when block is confirmed
                confirmations: 0
            )
            
            // Add to pending messages
            pendingMessages.append(message)
            
            print("📤 Message sent via blockchain: \(content)")
            return TLSMessageResponse(
                success: true,
                txid: paymentResponse.txid,
                error: nil,
                blockHeight: nil
            )
        } else {
            return TLSMessageResponse(
                success: false,
                txid: nil,
                error: paymentResponse.error,
                blockHeight: nil
            )
        }
    }
    
    // MARK: - Message Encryption/Decryption
    private func encryptMessage(_ content: String, for recipientAddress: String) -> String? {
        // In a real implementation, this would use the recipient's public key
        // For now, we'll use a simple encryption method
        
        guard let data = content.data(using: .utf8) else { return nil }
        
        // Create a unique encryption key based on recipient address
        let keyData = recipientAddress.data(using: .utf8) ?? Data()
        let key = SHA256.hash(data: keyData)
        
        // Simple XOR encryption (in production, use proper asymmetric encryption)
        var encryptedData = Data()
        let keyArray = Array(key)
        for (index, byte) in data.enumerated() {
            let keyIndex = index % keyArray.count
            let keyByte = keyArray[keyIndex]
            encryptedData.append(byte ^ keyByte)
        }
        
        return encryptedData.base64EncodedString()
    }
    
    func decryptMessage(_ encryptedContent: String, from senderAddress: String) -> String? {
        // In a real implementation, this would use the sender's public key
        // For now, we'll use a simple decryption method
        
        guard let encryptedData = Data(base64Encoded: encryptedContent) else { return nil }
        
        // Create the same key used for encryption
        let keyData = senderAddress.data(using: .utf8) ?? Data()
        let key = SHA256.hash(data: keyData)
        
        // Simple XOR decryption
        var decryptedData = Data()
        let keyArray = Array(key)
        for (index, byte) in encryptedData.enumerated() {
            let keyIndex = index % keyArray.count
            let keyByte = keyArray[keyIndex]
            decryptedData.append(byte ^ keyByte)
        }
        
        return String(data: decryptedData, encoding: .utf8)
    }
    
    // MARK: - Conversation Management
    private func updateConversation(with message: TLSMessage) {
        let conversationId = getConversationId(for: message)
        
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            // Update existing conversation
            conversations[index].lastMessage = message
            conversations[index].updatedAt = Date()
            conversations[index].unreadCount += 1
        } else {
            // Create new conversation
            let newConversation = TLSConversation(
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
    
    private func getConversationId(for message: TLSMessage) -> String {
        let participants = [message.senderAddress, message.receiverAddress].sorted()
        return participants.joined(separator: "_")
    }
    
    // MARK: - Message Loading
    private func loadMessagesFromBlockchain() async {
        guard let address = walletService.loadAddress() else { return }
        
        // Load recent transactions that contain messages
        let transactions = await tlsService.getTransactionHistory(address: address)
        
        for transaction in transactions {
            if let messageData = extractMessageFromTransaction(transaction) {
                let message = TLSMessage(
                    id: transaction.txid,
                    senderAddress: transaction.from ?? "",
                    receiverAddress: transaction.to ?? "",
                    content: messageData.content,
                    encryptedContent: messageData.encryptedContent,
                    timestamp: Date(timeIntervalSince1970: TimeInterval(transaction.timestamp)),
                    messageType: messageData.messageType,
                    signature: messageData.signature,
                    txid: transaction.txid,
                    blockHeight: nil, // TLSTransaction doesn't have blockHeight
                    confirmations: transaction.confirmations
                )
                
                messages.append(message)
                updateConversation(with: message)
            }
        }
        
        print("📚 Loaded \(messages.count) messages from blockchain")
    }
    
    // MARK: - Message Verification
    func verifyMessageSignature(_ message: TLSMessage) -> Bool {
        // In a real implementation, this would verify the signature using the sender's public key
        // For now, we'll return true if signature exists
        return !message.signature.isEmpty
    }
    
    // MARK: - Group Chat Support
    func sendGroupMessage(to groupAddress: String, content: String) async -> TLSMessageResponse {
        // Group messages are sent to a special group address
        return await sendMessage(to: groupAddress, content: content, messageType: .group)
    }
    
    // MARK: - Payment Messages
    func sendPaymentMessage(to receiverAddress: String, amount: Double, message: String) async -> TLSMessageResponse {
        // Payment messages include actual TLS transfer
        return await sendMessage(to: receiverAddress, content: message, messageType: .payment)
    }
}

// MARK: - TLS Conversation Model
struct TLSConversation: Identifiable, Codable {
    let id: String
    let participants: [String]
    var lastMessage: TLSMessage?
    var unreadCount: Int
    let createdAt: Date
    var updatedAt: Date
    let isGroupChat: Bool
    let groupName: String?
    let groupAvatar: String?
} 