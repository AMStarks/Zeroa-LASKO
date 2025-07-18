import Foundation
import Combine

// MARK: - Coin Service Protocol
@preconcurrency
protocol CoinServiceProtocol: Sendable {
    var coinType: CoinType { get }
    var isConnected: Bool { get }
    var lastBlockHeight: Int { get }
    
    func initialize(completion: @escaping () -> Void)
    func deriveAddress(from mnemonic: String, completion: @escaping (Bool, String?) -> Void)
    func getBalance(address: String, completion: @escaping (WalletBalance) -> Void)
    func sendTransaction(request: SendTransactionRequest, completion: @escaping (SendTransactionResponse) -> Void)
    func getTransactionHistory(address: String, completion: @escaping ([WalletTransaction]) -> Void)
    func checkNetworkStatus(completion: @escaping (Bool) -> Void)
    func estimateFee(priority: SendTransactionRequest.TransactionPriority, completion: @escaping (Double) -> Void)
    func clear()
}

// MARK: - Blockchain API Protocol
protocol BlockchainAPIProtocol {
    var baseURL: String { get }
    var networkName: String { get }
    
    func getAddressInfo(address: String) async -> AddressInfo?
    func getTransactionInfo(txid: String) async -> TransactionInfo?
    func getBlockInfo(blockHeight: Int) async -> BlockInfo?
    func getCurrentBlockHeight() async -> Int
    func broadcastTransaction(hexTransaction: String) async -> BroadcastResponse?
    func getFeeEstimates() async -> FeeEstimates?
}

// MARK: - Key Derivation Protocol
protocol KeyDerivationProtocol {
    func derivePrivateKey(from mnemonic: String, path: String) -> Data?
    func derivePublicKey(from privateKey: Data) -> Data?
    func deriveAddress(from publicKey: Data, coinType: CoinType) -> String?
    func validateAddress(_ address: String, coinType: CoinType) -> Bool
}

// MARK: - Transaction Builder Protocol
protocol TransactionBuilderProtocol {
    func buildTransaction(
        fromAddress: String,
        toAddress: String,
        amount: Double,
        fee: Double,
        privateKey: Data
    ) -> TransactionData?
    
    func signTransaction(_ transaction: TransactionData, privateKey: Data) -> String?
    func validateTransaction(_ hexTransaction: String) -> Bool
}

// MARK: - Network Monitor Protocol
protocol NetworkMonitorProtocol: ObservableObject {
    var isConnected: Bool { get }
    var lastBlockHeight: Int { get }
    var networkDifficulty: Double { get }
    
    func startMonitoring()
    func stopMonitoring()
    func getNetworkStats() -> NetworkStats
}

// MARK: - Coin Types
enum CoinType: String, CaseIterable, Codable {
    case bitcoin = "BTC"
    case flux = "FLUX"
    case litecoin = "LTC"
    case kaspa = "KAS"
    
    var name: String {
        switch self {
        case .bitcoin: return "Bitcoin"
        case .flux: return "Flux"
        case .litecoin: return "Litecoin"
        case .kaspa: return "Kaspa"
        }
    }
    
    var symbol: String {
        return rawValue
    }
    
    var derivationPath: String {
        switch self {
        case .bitcoin: return "m/44'/0'/0'/0/0"
        case .flux: return "m/44'/0'/0'/0/0"
        case .litecoin: return "m/44'/2'/0'/0/0"
        case .kaspa: return "m/44'/111111'/0'/0/0"
        }
    }
    
    var decimals: Int {
        return 8
    }
    
    var icon: String {
        switch self {
        case .bitcoin: return "bitcoin"
        case .flux: return "flux"
        case .litecoin: return "litecoin"
        case .kaspa: return "kaspa"
        }
    }
}

// MARK: - Wallet Models
struct WalletBalance: Codable, Identifiable {
    var id = UUID()
    let coinType: CoinType
    let confirmed: Double
    let unconfirmed: Double
    let total: Double
    let lastUpdated: Date
    
    var formattedTotal: String {
        return String(format: "%.8f", total)
    }
    
    var formattedConfirmed: String {
        return String(format: "%.8f", confirmed)
    }
    
    var formattedUnconfirmed: String {
        return String(format: "%.8f", unconfirmed)
    }
}

struct WalletTransaction: Codable, Identifiable {
    var id = UUID()
    let coinType: CoinType
    let txid: String
    let amount: Double
    let fee: Double
    let confirmations: Int
    let timestamp: Date
    let type: TransactionType
    let fromAddress: String?
    let toAddress: String?
    let blockHeight: Int?
    let status: TransactionStatus
    
    enum TransactionType: String, Codable {
        case send = "send"
        case receive = "receive"
        case unknown = "unknown"
    }
    
    enum TransactionStatus: String, Codable {
        case pending = "pending"
        case confirmed = "confirmed"
        case failed = "failed"
    }
    
    var formattedAmount: String {
        return String(format: "%.8f", abs(amount))
    }
    
    var formattedFee: String {
        return String(format: "%.8f", fee)
    }
    
    var isConfirmed: Bool {
        return status == .confirmed
    }
    
    var isPending: Bool {
        return status == .pending
    }
    
    var isFailed: Bool {
        return status == .failed
    }
}

struct SendTransactionRequest: Codable {
    let fromAddress: String
    let toAddress: String
    let amount: Double
    let fee: Double?
    let priority: TransactionPriority
    let coinType: CoinType
    
    enum TransactionPriority: String, Codable, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        
        var displayName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
    }
}

struct SendTransactionResponse: Codable {
    let success: Bool
    let txid: String?
    let error: String?
    let fee: Double?
    let confirmations: Int?
}

// MARK: - API Models
struct AddressInfo: Codable {
    let address: String
    let balance: Double
    let unconfirmedBalance: Double
    let totalReceived: Double
    let totalSent: Double
    let transactionCount: Int
    let transactions: [TransactionInfo]
}

struct TransactionInfo: Codable {
    let txid: String
    let amount: Double
    let fee: Double
    let confirmations: Int
    let timestamp: Date
    let blockHeight: Int?
    let fromAddress: String?
    let toAddress: String?
    let type: String
    let status: String
}

struct BlockInfo: Codable {
    let height: Int
    let hash: String
    let timestamp: Date
    let transactionCount: Int
    let size: Int
    let difficulty: Double
}

struct BroadcastResponse: Codable {
    let success: Bool
    let txid: String?
    let error: String?
}

struct FeeEstimates: Codable {
    let low: Double
    let medium: Double
    let high: Double
    let timestamp: Date
}

struct TransactionData: Codable {
    let hexTransaction: String
    let txid: String
    let fee: Double
    let size: Int
}

struct NetworkStats: Codable {
    let isConnected: Bool
    let lastBlockHeight: Int
    let networkDifficulty: Double
    let averageBlockTime: Double
    let totalTransactions: Int
    let networkHashrate: Double?
} 