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
    let type: String // "send", "receive", "stake"
    let from: String?
    let to: String?
}

struct TLSPaymentRequest: Codable {
    let fromAddress: String
    let toAddress: String
    let amount: Double
    let fee: Double
    let message: String?
}

struct TLSPaymentResponse: Codable {
    let success: Bool
    let txid: String?
    let error: String?
}

// MARK: - TLS Blockchain Service
class TLSBlockchainService: ObservableObject {
    static let shared = TLSBlockchainService()
    
    private let baseURL = "https://telestai.cryptoscope.io/api"
    private let walletService = WalletService.shared
    
    @Published var isConnected = false
    @Published var currentBalance: Double = 0.0
    @Published var recentTransactions: [TLSTransaction] = []
    
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
    
    func sendPayment(toAddress: String, amount: Double, message: String? = nil) async -> TLSPaymentResponse {
        guard let fromAddress = walletService.loadAddress() else {
            return TLSPaymentResponse(success: false, txid: nil, error: "No wallet address found")
        }
        
        // For now, we'll simulate the payment since we need the actual TLS wallet integration
        // In a real implementation, this would use the TLS wallet to sign and broadcast the transaction
        
        _ = TLSPaymentRequest(
            fromAddress: fromAddress,
            toAddress: toAddress,
            amount: amount,
            fee: 0.001, // Standard TLS fee
            message: message
        )
        
        // Simulate payment processing
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Mock successful payment
        let mockTxid = "TLS" + String((0..<64).map { _ in "0123456789abcdef".randomElement()! })
        
        return TLSPaymentResponse(
            success: true,
            txid: mockTxid,
            error: nil
        )
    }
    
    func getTransactionHistory(address: String) async -> [TLSTransaction] {
        guard let url = URL(string: "\(baseURL)/address/\(address)/transactions") else { return [] }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let transactions = try JSONDecoder().decode([TLSTransaction].self, from: data)
                await MainActor.run {
                    self.recentTransactions = transactions
                }
                return transactions
            }
        } catch {
            print("Error fetching transaction history: \(error)")
        }
        
        return []
    }
    
    // MARK: - Subscription Payment
    func processSubscriptionPayment() async -> Bool {
        // Subscription payment to a designated TLS address
        let subscriptionAddress = "TLS_SUBSCRIPTION_ADDRESS" // Replace with actual subscription address
        let subscriptionAmount = 10.0 // 10 TLS for subscription
        
        let paymentResponse = await sendPayment(
            toAddress: subscriptionAddress,
            amount: subscriptionAmount,
            message: "PAAI App Subscription"
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