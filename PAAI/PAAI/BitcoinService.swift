import Foundation
import CryptoKit
import Combine

// MARK: - Bitcoin Service Implementation
@MainActor
@preconcurrency
class BitcoinService: CoinServiceProtocol {
    let coinType: CoinType = .bitcoin
    
    @Published var isConnected = false
    @Published var lastBlockHeight = 0
    
    private let api: BitcoinAPI
    private let keyDerivation: BitcoinKeyDerivation
    private let transactionBuilder: BitcoinTransactionBuilder
    private let networkMonitor: BitcoinNetworkMonitor
    
    init() {
        self.api = BitcoinAPI()
        self.keyDerivation = BitcoinKeyDerivation()
        self.transactionBuilder = BitcoinTransactionBuilder()
        self.networkMonitor = BitcoinNetworkMonitor()
        
        setupNetworkMonitoring()
    }
    
    // MARK: - Initialization
    func initialize(completion: @escaping () -> Void) {
        Task {
            await checkNetworkStatus { [weak self] isConnected in
                DispatchQueue.main.async {
                    self?.isConnected = isConnected
                    completion()
                }
            }
        }
    }
    
    // MARK: - Address Derivation
    func deriveAddress(from mnemonic: String, completion: @escaping (Bool, String?) -> Void) {
        guard let privateKey = keyDerivation.derivePrivateKey(from: mnemonic, path: coinType.derivationPath),
              let publicKey = keyDerivation.derivePublicKey(from: privateKey),
              let address = keyDerivation.deriveAddress(from: publicKey, coinType: coinType) else {
            completion(false, nil)
            return
        }
        
        completion(true, address)
    }
    
    // MARK: - Balance Management
    func getBalance(address: String, completion: @escaping (WalletBalance) -> Void) {
        Task {
            guard let addressInfo = await api.getAddressInfo(address: address) else {
                let emptyBalance = WalletBalance(
                    coinType: coinType,
                    confirmed: 0.0,
                    unconfirmed: 0.0,
                    total: 0.0,
                    lastUpdated: Date()
                )
                completion(emptyBalance)
                return
            }
            
            let balance = WalletBalance(
                coinType: coinType,
                confirmed: addressInfo.balance,
                unconfirmed: addressInfo.unconfirmedBalance,
                total: addressInfo.balance + addressInfo.unconfirmedBalance,
                lastUpdated: Date()
            )
            
            completion(balance)
        }
    }
    
    // MARK: - Transaction Management
    func sendTransaction(request: SendTransactionRequest, completion: @escaping (SendTransactionResponse) -> Void) {
        Task {
            // Get current balance
            guard let addressInfo = await api.getAddressInfo(address: request.fromAddress) else {
                completion(SendTransactionResponse(success: false, txid: nil, error: "Failed to get address info", fee: nil, confirmations: nil))
                return
            }
            
            // Check balance
            let totalBalance = addressInfo.balance + addressInfo.unconfirmedBalance
            let estimatedFee = await getEstimatedFee(priority: request.priority)
            let fee = request.fee ?? estimatedFee
            let totalRequired = request.amount + fee
            
            guard totalBalance >= totalRequired else {
                completion(SendTransactionResponse(success: false, txid: nil, error: "Insufficient balance", fee: fee, confirmations: nil))
                return
            }
            
            // Build and sign transaction
            guard let privateKey = getPrivateKey(for: request.fromAddress),
                  let transactionData = transactionBuilder.buildTransaction(
                    fromAddress: request.fromAddress,
                    toAddress: request.toAddress,
                    amount: request.amount,
                    fee: fee,
                    privateKey: privateKey
                  ),
                  let signedTransaction = transactionBuilder.signTransaction(transactionData, privateKey: privateKey) else {
                completion(SendTransactionResponse(success: false, txid: nil, error: "Failed to build transaction", fee: fee, confirmations: nil))
                return
            }
            
            // Broadcast transaction
            guard let broadcastResponse = await api.broadcastTransaction(hexTransaction: signedTransaction) else {
                completion(SendTransactionResponse(success: false, txid: nil, error: "Failed to broadcast transaction", fee: fee, confirmations: nil))
                return
            }
            
            if broadcastResponse.success {
                completion(SendTransactionResponse(
                    success: true,
                    txid: broadcastResponse.txid,
                    error: nil,
                    fee: fee,
                    confirmations: 0
                ))
            } else {
                completion(SendTransactionResponse(
                    success: false,
                    txid: nil,
                    error: broadcastResponse.error,
                    fee: fee,
                    confirmations: nil
                ))
            }
        }
    }
    
    // MARK: - Transaction History
    func getTransactionHistory(address: String, completion: @escaping ([WalletTransaction]) -> Void) {
        Task {
            guard let addressInfo = await api.getAddressInfo(address: address) else {
                completion([])
                return
            }
            
            let transactions = addressInfo.transactions.map { txInfo in
                WalletTransaction(
                    coinType: coinType,
                    txid: txInfo.txid,
                    amount: txInfo.amount,
                    fee: txInfo.fee,
                    confirmations: txInfo.confirmations,
                    timestamp: txInfo.timestamp,
                    type: determineTransactionType(txInfo),
                    fromAddress: txInfo.fromAddress,
                    toAddress: txInfo.toAddress,
                    blockHeight: txInfo.blockHeight,
                    status: determineTransactionStatus(txInfo)
                )
            }
            
            completion(transactions)
        }
    }
    
    // MARK: - Network Status
    func checkNetworkStatus(completion: @escaping (Bool) -> Void) {
        Task {
            let blockHeight = await api.getCurrentBlockHeight()
            let isConnected = blockHeight > 0
            
            DispatchQueue.main.async {
                self.isConnected = isConnected
                self.lastBlockHeight = blockHeight
                completion(isConnected)
            }
        }
    }
    
    // MARK: - Fee Estimation
    func estimateFee(priority: SendTransactionRequest.TransactionPriority, completion: @escaping (Double) -> Void) {
        Task {
            let fee = await getEstimatedFee(priority: priority)
            completion(fee)
        }
    }
    
    // MARK: - Private Methods
    private func setupNetworkMonitoring() {
        networkMonitor.startMonitoring()
        
        networkMonitor.$isConnected
            .assign(to: \.isConnected, on: self)
            .store(in: &cancellables)
        
        networkMonitor.$lastBlockHeight
            .assign(to: \.lastBlockHeight, on: self)
            .store(in: &cancellables)
    }
    
    private func getPrivateKey(for address: String) -> Data? {
        // In a real implementation, this would retrieve the private key from secure storage
        // For now, we'll return a mock private key
        return Data(repeating: 0x01, count: 32)
    }
    
    private func getEstimatedFee(priority: SendTransactionRequest.TransactionPriority) async -> Double {
        guard let feeEstimates = await api.getFeeEstimates() else {
            // Fallback fees in satoshis per byte
            let fallbackFees: [SendTransactionRequest.TransactionPriority: Double] = [
                .low: 5.0,
                .medium: 10.0,
                .high: 20.0
            ]
            return fallbackFees[priority] ?? 10.0
        }
        
        switch priority {
        case .low:
            return feeEstimates.low
        case .medium:
            return feeEstimates.medium
        case .high:
            return feeEstimates.high
        }
    }
    
    private func determineTransactionType(_ txInfo: TransactionInfo) -> WalletTransaction.TransactionType {
        if txInfo.amount > 0 {
            return .receive
        } else {
            return .send
        }
    }
    
    private func determineTransactionStatus(_ txInfo: TransactionInfo) -> WalletTransaction.TransactionStatus {
        if txInfo.confirmations >= 6 {
            return .confirmed
        } else if txInfo.confirmations > 0 {
            return .pending
        } else {
            return .failed
        }
    }
    
    // MARK: - Cleanup
    func clear() {
        networkMonitor.stopMonitoring()
        cancellables.removeAll()
    }
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Bitcoin API
class BitcoinAPI: BlockchainAPIProtocol {
    let baseURL = "https://blockstream.info/api"
    let networkName = "Bitcoin"
    
    func getAddressInfo(address: String) async -> AddressInfo? {
        guard let url = URL(string: "\(baseURL)/address/\(address)") else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let addressInfo = try JSONDecoder().decode(AddressInfo.self, from: data)
                return addressInfo
            }
        } catch {
            print("Bitcoin API error: \(error)")
        }
        
        return nil
    }
    
    func getTransactionInfo(txid: String) async -> TransactionInfo? {
        guard let url = URL(string: "\(baseURL)/tx/\(txid)") else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let transactionInfo = try JSONDecoder().decode(TransactionInfo.self, from: data)
                return transactionInfo
            }
        } catch {
            print("Bitcoin transaction API error: \(error)")
        }
        
        return nil
    }
    
    func getBlockInfo(blockHeight: Int) async -> BlockInfo? {
        guard let url = URL(string: "\(baseURL)/block-height/\(blockHeight)") else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let blockInfo = try JSONDecoder().decode(BlockInfo.self, from: data)
                return blockInfo
            }
        } catch {
            print("Bitcoin block API error: \(error)")
        }
        
        return nil
    }
    
    func getCurrentBlockHeight() async -> Int {
        guard let url = URL(string: "\(baseURL)/blocks/tip/height") else { return 0 }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let height = String(data: data, encoding: .utf8) ?? "0"
                return Int(height) ?? 0
            }
        } catch {
            print("Bitcoin height API error: \(error)")
        }
        
        return 0
    }
    
    func broadcastTransaction(hexTransaction: String) async -> BroadcastResponse? {
        guard let url = URL(string: "\(baseURL)/tx") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = hexTransaction.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    let txid = String(data: data, encoding: .utf8) ?? ""
                    return BroadcastResponse(success: true, txid: txid, error: nil)
                } else {
                    let error = String(data: data, encoding: .utf8) ?? "Unknown error"
                    return BroadcastResponse(success: false, txid: nil, error: error)
                }
            }
        } catch {
            print("Bitcoin broadcast error: \(error)")
        }
        
        return BroadcastResponse(success: false, txid: nil, error: "Network error")
    }
    
    func getFeeEstimates() async -> FeeEstimates? {
        guard let url = URL(string: "\(baseURL)/fee-estimates") else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let feeEstimates = try JSONDecoder().decode(FeeEstimates.self, from: data)
                return feeEstimates
            }
        } catch {
            print("Bitcoin fee estimates error: \(error)")
        }
        
        return nil
    }
}

// MARK: - Bitcoin Key Derivation
class BitcoinKeyDerivation: KeyDerivationProtocol {
    func derivePrivateKey(from mnemonic: String, path: String) -> Data? {
        // In a real implementation, this would use BIP39 and BIP32 for proper HD wallet derivation
        // For now, we'll return a mock private key
        return Data(repeating: 0x01, count: 32)
    }
    
    func derivePublicKey(from privateKey: Data) -> Data? {
        // In a real implementation, this would use secp256k1 curve
        // For now, we'll return a mock public key
        return Data(repeating: 0x02, count: 33)
    }
    
    func deriveAddress(from publicKey: Data, coinType: CoinType) -> String? {
        // In a real implementation, this would use proper Bitcoin address generation
        // For now, we'll return a mock address
        return "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
    }
    
    func validateAddress(_ address: String, coinType: CoinType) -> Bool {
        // Basic Bitcoin address validation
        let patterns = [
            "^1[a-km-zA-HJ-NP-Z1-9]{25,34}$", // Legacy
            "^3[a-km-zA-HJ-NP-Z1-9]{25,34}$", // SegWit
            "^bc1[a-z0-9]{39,59}$" // Native SegWit
        ]
        
        return patterns.contains { pattern in
            address.range(of: pattern, options: .regularExpression) != nil
        }
    }
}

// MARK: - Bitcoin Transaction Builder
class BitcoinTransactionBuilder: TransactionBuilderProtocol {
    func buildTransaction(
        fromAddress: String,
        toAddress: String,
        amount: Double,
        fee: Double,
        privateKey: Data
    ) -> TransactionData? {
        // In a real implementation, this would build a proper Bitcoin transaction
        // For now, we'll return mock transaction data
        let mockHex = "0100000001" + String(repeating: "0", count: 64) + "0000000000"
        return TransactionData(
            hexTransaction: mockHex,
            txid: "mock_txid_" + String((0..<64).map { _ in "0123456789abcdef".randomElement()! }),
            fee: fee,
            size: 250
        )
    }
    
    func signTransaction(_ transaction: TransactionData, privateKey: Data) -> String? {
        // In a real implementation, this would properly sign the transaction
        // For now, we'll return the hex transaction as-is
        return transaction.hexTransaction
    }
    
    func validateTransaction(_ hexTransaction: String) -> Bool {
        // Basic validation - check if it's a valid hex string
        return hexTransaction.range(of: "^[0-9a-fA-F]+$", options: .regularExpression) != nil
    }
}

// MARK: - Bitcoin Network Monitor
class BitcoinNetworkMonitor: NetworkMonitorProtocol {
    @Published var isConnected = false
    @Published var lastBlockHeight = 0
    @Published var networkDifficulty = 0.0
    
    private var timer: Timer?
    private let api = BitcoinAPI()
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.updateNetworkStats()
            }
        }
        
        // Initial update
        Task {
            await updateNetworkStats()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func getNetworkStats() -> NetworkStats {
        return NetworkStats(
            isConnected: isConnected,
            lastBlockHeight: lastBlockHeight,
            networkDifficulty: networkDifficulty,
            averageBlockTime: 600.0, // 10 minutes
            totalTransactions: 0,
            networkHashrate: nil
        )
    }
    
    private func updateNetworkStats() async {
        let blockHeight = await api.getCurrentBlockHeight()
        
        await MainActor.run {
            self.isConnected = blockHeight > 0
            self.lastBlockHeight = blockHeight
        }
    }
} 