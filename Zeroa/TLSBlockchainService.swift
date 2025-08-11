import Foundation
import CryptoKit

// MARK: - TLS Blockchain Models
struct TLSAddress: Codable {
    let address: String
    let balance: Double
    let transactions: [TLSTransaction]
}

struct TLSTransaction: Codable {
    let txid: String
    let amount: Double
    let fee: Double
    let confirmations: Int
    let timestamp: Int
    let type: String // "send", "receive", "stake", "message"
    let from: String?
    let to: String?
    let message: String? // Encrypted message data
    let messageType: String? // "text", "payment", "identity", "system", "group"
}

struct TLSPaymentRequest: Codable {
    let fromAddress: String
    let toAddress: String
    let amount: Double
    let fee: Double
    let message: String?
    let messageType: String?
}

struct TLSPaymentResponse: Codable {
    let success: Bool
    let txid: String?
    let error: String?
    let blockHeight: Int?
}

// MARK: - TLS Message Transaction Models (Enhanced)
struct TLSBlockchainMessageTransaction: Codable {
    let txid: String
    let fromAddress: String
    let toAddress: String
    let amount: Double
    let fee: Double
    let message: String
    let messageType: String
    let timestamp: Date
    let blockHeight: Int
    let confirmations: Int
    let signature: String
}

struct TLSBlockchainMessageRequest: Codable {
    let fromAddress: String
    let toAddress: String
    let encryptedMessage: String
    let messageType: String
    let amount: Double
    let fee: Double
    let signature: String
}

// MARK: - TLS Blockchain Service
class TLSBlockchainService: ObservableObject {
    static let shared = TLSBlockchainService()
    
    private let baseURL = "https://telestai.cryptoscope.io/api"
    private let walletService = WalletService.shared
    
    @Published var isConnected = false
    @Published var currentBalance: Double = 0.0
    @Published var recentTransactions: [TLSTransaction] = []
    @Published var lastBlockHeight: Int = 0
    
    // MARK: - Network Methods
    func checkConnection() async -> Bool {
        guard let url = URL(string: "\(baseURL)/stats/") else { return false }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                isConnected = httpResponse.statusCode == 200
                return isConnected
            }
        } catch {
            print("TLS connection error: \(error)")
        }
        
        isConnected = false
        return false
    }
    
    func getAddressInfo(address: String) async -> TLSAddress? {
        guard let url = URL(string: "\(baseURL)/address/\(address)") else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let addressInfo = try JSONDecoder().decode(TLSAddress.self, from: data)
                await MainActor.run {
                    self.currentBalance = addressInfo.balance
                    self.recentTransactions = addressInfo.transactions
                }
                return addressInfo
            }
        } catch {
            print("Error fetching address info: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Enhanced Payment with Message Support
    func sendPayment(toAddress: String, amount: Double, message: String? = nil, messageType: String? = nil) async -> TLSPaymentResponse {
        guard let fromAddress = walletService.loadAddress() else {
            return TLSPaymentResponse(success: false, txid: nil, error: "No wallet address found", blockHeight: nil)
        }
        
        // Create payment request with message data
        let paymentRequest = TLSPaymentRequest(
            fromAddress: fromAddress,
            toAddress: toAddress,
            amount: amount,
            fee: 0.001, // Standard TLS fee
            message: message,
            messageType: messageType
        )
        
        // In a real implementation, this would use the TLS wallet to sign and broadcast the transaction
        // For now, we'll simulate the payment with message support
        
        // Simulate payment processing
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Mock successful payment with message
        let mockTxid = "TLS" + String((0..<64).map { _ in "0123456789abcdef".randomElement()! })
        let mockBlockHeight = Int.random(in: 1000000...9999999)
        
        // Create transaction record
        let transaction = TLSTransaction(
            txid: mockTxid,
            amount: amount,
            fee: 0.001,
            confirmations: 1,
            timestamp: Int(Date().timeIntervalSince1970),
            type: message != nil ? "message" : "send",
            from: fromAddress,
            to: toAddress,
            message: message,
            messageType: messageType
        )
        
        // Add to recent transactions
        await MainActor.run {
            self.recentTransactions.insert(transaction, at: 0)
            self.lastBlockHeight = mockBlockHeight
        }
        
        print("✅ Payment sent with message: \(message ?? "No message")")
        
        return TLSPaymentResponse(
            success: true,
            txid: mockTxid,
            error: nil,
            blockHeight: mockBlockHeight
        )
    }
    
    // MARK: - Message-Specific Transactions
    func sendMessageTransaction(toAddress: String, encryptedMessage: String, messageType: String = "text") async -> TLSPaymentResponse {
        // Send a message transaction (minimal amount, mostly for message delivery)
        return await sendPayment(
            toAddress: toAddress,
            amount: 0.0, // No actual payment, just message delivery
            message: encryptedMessage,
            messageType: messageType
        )
    }
    
    func sendPaymentMessage(toAddress: String, amount: Double, message: String) async -> TLSPaymentResponse {
        // Send a payment with an attached message
        return await sendPayment(
            toAddress: toAddress,
            amount: amount,
            message: message,
            messageType: "payment"
        )
    }
    
    // MARK: - Message Scanning
    func scanForMessages(address: String) async -> [TLSBlockchainMessageTransaction] {
        guard let addressInfo = await getAddressInfo(address: address) else { return [] }
        
        var messageTransactions: [TLSBlockchainMessageTransaction] = []
        
        for transaction in addressInfo.transactions {
            // Check if transaction contains a message
            if let message = transaction.message, let messageType = transaction.messageType {
                let messageTransaction = TLSBlockchainMessageTransaction(
                    txid: transaction.txid,
                    fromAddress: transaction.from ?? "",
                    toAddress: transaction.to ?? "",
                    amount: transaction.amount,
                    fee: transaction.fee,
                    message: message,
                    messageType: messageType,
                    timestamp: Date(timeIntervalSince1970: TimeInterval(transaction.timestamp)),
                    blockHeight: 0, // Would be actual block height in real implementation
                    confirmations: transaction.confirmations,
                    signature: "" // Would be actual signature in real implementation
                )
                messageTransactions.append(messageTransaction)
            }
        }
        
        return messageTransactions
    }
    
    // MARK: - Block Height Monitoring
    func getCurrentBlockHeight() async -> Int {
        // In a real implementation, this would query the blockchain for current block height
        // For now, we'll simulate with a random block height
        return Int.random(in: 1000000...9999999)
    }
    
    func getBlockInfo(blockHeight: Int) async -> [String: Any]? {
        // In a real implementation, this would fetch block information
        // For now, we'll return mock data
        return [
            "height": blockHeight,
            "hash": "TLS" + String((0..<64).map { _ in "0123456789abcdef".randomElement()! }),
            "timestamp": Int(Date().timeIntervalSince1970),
            "transactions": []
        ]
    }
    
    // MARK: - Transaction History
    func getTransactionHistory(address: String) async -> [TLSTransaction] {
        guard let addressInfo = await getAddressInfo(address: address) else { return [] }
        return addressInfo.transactions
    }
    
    // MARK: - Message Transaction History
    func getMessageTransactionHistory(address: String) async -> [TLSBlockchainMessageTransaction] {
        return await scanForMessages(address: address)
    }
    
    // MARK: - Subscription Payment
    func processSubscriptionPayment() async -> Bool {
        // Subscription payment to a designated TLS address
        let subscriptionAddress = "TLS_SUBSCRIPTION_ADDRESS" // Replace with actual subscription address
        let subscriptionAmount = 10.0 // 10 TLS for subscription
        
        let paymentResponse = await sendPayment(
            toAddress: subscriptionAddress,
            amount: subscriptionAmount,
            message: "PAAI App Subscription",
            messageType: "system"
        )
        
        if paymentResponse.success {
            // Save subscription status
            let date = ISO8601DateFormatter().string(from: Date())
            _ = walletService.keychain.save(key: "last_payment", value: date)
            _ = walletService.keychain.save(key: "subscription_txid", value: paymentResponse.txid ?? "")
            return true
        }
        
        return false
    }
    
    // MARK: - Balance Check
    func refreshBalance() async {
        guard let address = walletService.loadAddress() else { return }
        _ = await getAddressInfo(address: address)
    }
    
    // MARK: - On-Ramp Integration (Future)
    func getOnRampOptions() -> [String] {
        // Future implementation for fiat-to-TLS on-ramp
        return [
            "Credit Card",
            "Bank Transfer", 
            "Crypto Exchange",
            "P2P Trading"
        ]
    }
    
    func initiateOnRamp(method: String, amount: Double) async -> Bool {
        // Future implementation for on-ramp processing
        // This would integrate with services like MoonPay, Ramp, etc.
        print("Initiating on-ramp: \(method) for \(amount) TLS")
        return true
    }
    
    // MARK: - Message Verification
    func verifyMessageTransaction(_ transaction: TLSBlockchainMessageTransaction) -> Bool {
        // In a real implementation, this would verify the transaction signature
        // For now, we'll return true if the transaction has a message
        return !transaction.message.isEmpty
    }
    
    // MARK: - Group Chat Support
    func sendGroupMessage(groupAddress: String, message: String, messageType: String = "group") async -> TLSPaymentResponse {
        // Send message to a group address (special address for group chats)
        return await sendMessageTransaction(
            toAddress: groupAddress,
            encryptedMessage: message,
            messageType: messageType
        )
    }
}

// MARK: - Extensions
extension TLSBlockchainService {
    func formatBalance(_ balance: Double) -> String {
        return String(format: "%.6f TLS", balance)
    }
    
    func formatAmount(_ amount: Double) -> String {
        return String(format: "%.6f", amount)
    }
} 