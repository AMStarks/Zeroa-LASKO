import Foundation
import CryptoKit
import Combine

// MARK: - AI Companion Models

/// Represents a personalized AI companion's personality and characteristics
struct CompanionPersonality: Codable {
    let id: String
    let name: String
    let description: String
    let communicationStyle: CommunicationStyle
    let expertiseAreas: [ExpertiseArea]
    let interactionFrequency: InteractionFrequency
    let privacyLevel: PrivacyLevel
    let responseLength: ResponseLength
    let emotionalTone: EmotionalTone
    let customTraits: [String: String]
    
    enum CommunicationStyle: String, Codable, CaseIterable {
        case formal = "formal"
        case casual = "casual"
        case technical = "technical"
        case creative = "creative"
        case friendly = "friendly"
        case professional = "professional"
    }
    
    enum ExpertiseArea: String, Codable, CaseIterable {
        case finance = "finance"
        case technology = "technology"
        case health = "health"
        case creativity = "creativity"
        case education = "education"
        case entertainment = "entertainment"
        case business = "business"
        case personal = "personal"
    }
    
    enum InteractionFrequency: String, Codable, CaseIterable {
        case reactive = "reactive"
        case proactive = "proactive"
        case balanced = "balanced"
    }
    
    enum PrivacyLevel: String, Codable, CaseIterable {
        case minimal = "minimal"
        case standard = "standard"
        case comprehensive = "comprehensive"
    }
    
    enum ResponseLength: String, Codable, CaseIterable {
        case concise = "concise"
        case detailed = "detailed"
        case adaptive = "adaptive"
    }
    
    enum EmotionalTone: String, Codable, CaseIterable {
        case neutral = "neutral"
        case enthusiastic = "enthusiastic"
        case calm = "calm"
        case supportive = "supportive"
        case analytical = "analytical"
    }
}

/// Represents a conversation memory entry
struct ConversationMemory: Codable {
    let id: String
    let timestamp: Date
    let userInput: String
    let companionResponse: String
    let context: [String: Any]
    let emotionalContext: EmotionalContext
    let actionTaken: String?
    let userFeedback: UserFeedback?
    
    enum EmotionalContext: String, Codable {
        case happy = "happy"
        case sad = "sad"
        case stressed = "stressed"
        case excited = "excited"
        case neutral = "neutral"
        case frustrated = "frustrated"
    }
    
    enum UserFeedback: String, Codable {
        case positive = "positive"
        case negative = "negative"
        case neutral = "neutral"
    }
}

/// User preferences and learning data
struct UserPreferences: Codable {
    let userId: String
    let preferredTopics: [String]
    let communicationStyle: CompanionPersonality.CommunicationStyle
    let responseLength: CompanionPersonality.ResponseLength
    let privacySettings: PrivacySettings
    let learningData: LearningData
    
    struct PrivacySettings: Codable {
        let allowPersonalData: Bool
        let allowLocationData: Bool
        let allowBiometricData: Bool
        let dataRetentionDays: Int
    }
    
    struct LearningData: Codable {
        let interactionPatterns: [String: Int]
        let preferredTimes: [String: Int]
        let topicEngagement: [String: Double]
        let responseEffectiveness: [String: Double]
    }
}

/// Blockchain-based companion identity
struct CompanionIdentity: Codable {
    let blockchainAddress: String
    let publicKey: String
    let identityHash: String
    let creationTimestamp: Date
    let ownerAddress: String
    let permissions: [String: Bool]
}

// MARK: - AI Companion Service

/// Main AI companion service that manages personality, memory, and blockchain integration
class ZeroaAICompanion: ObservableObject {
    static let shared = ZeroaAICompanion()
    
    @Published var currentPersonality: CompanionPersonality?
    @Published var conversationHistory: [ConversationMemory] = []
    @Published var userPreferences: UserPreferences?
    @Published var companionIdentity: CompanionIdentity?
    @Published var isActive = false
    @Published var currentContext: [String: Any] = [:]
    
    private let walletService = WalletService.shared
    private let blockchainService = TLSBlockchainService.shared
    private let keychainService = KeychainService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        loadCompanionData()
        setupBlockchainIntegration()
    }
    
    // MARK: - Companion Management
    
    /// Creates a new AI companion with specified personality
    func createCompanion(
        name: String,
        description: String,
        personality: CompanionPersonality.CommunicationStyle,
        expertise: [CompanionPersonality.ExpertiseArea],
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard let userAddress = walletService.loadAddress() else {
            completion(false, "No wallet address found")
            return
        }
        
        let companionId = UUID().uuidString
        let personality = CompanionPersonality(
            id: companionId,
            name: name,
            description: description,
            communicationStyle: personality,
            expertiseAreas: expertise,
            interactionFrequency: .balanced,
            privacyLevel: .standard,
            responseLength: .adaptive,
            emotionalTone: .supportive,
            customTraits: [:]
        )
        
        // Create blockchain identity
        createBlockchainIdentity(for: companionId, owner: userAddress) { [weak self] success, identity in
            if success, let identity = identity {
                self?.currentPersonality = personality
                self?.companionIdentity = identity
                self?.saveCompanionData()
                completion(true, companionId)
            } else {
                completion(false, "Failed to create blockchain identity")
            }
        }
    }
    
    /// Loads existing companion data
    private func loadCompanionData() {
        if let personalityData = keychainService.read(key: "companion_personality"),
           let personality = try? JSONDecoder().decode(CompanionPersonality.self, from: personalityData.data(using: .utf8) ?? Data()) {
            currentPersonality = personality
        }
        
        if let preferencesData = keychainService.read(key: "user_preferences"),
           let preferences = try? JSONDecoder().decode(UserPreferences.self, from: preferencesData.data(using: .utf8) ?? Data()) {
            userPreferences = preferences
        }
        
        if let identityData = keychainService.read(key: "companion_identity"),
           let identity = try? JSONDecoder().decode(CompanionIdentity.self, from: identityData.data(using: .utf8) ?? Data()) {
            companionIdentity = identity
        }
        
        loadConversationHistory()
    }
    
    /// Saves companion data to secure storage
    private func saveCompanionData() {
        if let personality = currentPersonality,
           let data = try? JSONEncoder().encode(personality),
           let jsonString = String(data: data, encoding: .utf8) {
            _ = keychainService.save(key: "companion_personality", value: jsonString)
        }
        
        if let preferences = userPreferences,
           let data = try? JSONEncoder().encode(preferences),
           let jsonString = String(data: data, encoding: .utf8) {
            _ = keychainService.save(key: "user_preferences", value: jsonString)
        }
        
        if let identity = companionIdentity,
           let data = try? JSONEncoder().encode(identity),
           let jsonString = String(data: data, encoding: .utf8) {
            _ = keychainService.save(key: "companion_identity", value: jsonString)
        }
    }
    
    // MARK: - Blockchain Integration
    
    /// Creates blockchain identity for companion
    private func createBlockchainIdentity(for companionId: String, owner: String, completion: @escaping (Bool, CompanionIdentity?) -> Void) {
        let publicKey = generatePublicKey()
        let identityHash = generateIdentityHash(companionId: companionId, owner: owner)
        
        let identity = CompanionIdentity(
            blockchainAddress: generateBlockchainAddress(),
            publicKey: publicKey,
            identityHash: identityHash,
            creationTimestamp: Date(),
            ownerAddress: owner,
            permissions: [
                "read_messages": true,
                "write_messages": true,
                "access_preferences": true,
                "modify_personality": false
            ]
        )
        
        // Store identity on blockchain
        storeIdentityOnBlockchain(identity) { success in
            completion(success, success ? identity : nil)
        }
    }
    
    /// Stores companion identity on TLS blockchain
    private func storeIdentityOnBlockchain(_ identity: CompanionIdentity, completion: @escaping (Bool) -> Void) {
        let identityData = [
            "type": "companion_identity",
            "address": identity.blockchainAddress,
            "public_key": identity.publicKey,
            "identity_hash": identity.identityHash,
            "owner": identity.ownerAddress,
            "permissions": identity.permissions,
            "timestamp": ISO8601DateFormatter().string(from: identity.creationTimestamp)
        ]
        
        // Convert to encrypted message for blockchain storage
        if let jsonData = try? JSONSerialization.data(withJSONObject: identityData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            
            // Store as blockchain message
            Task {
                let response = await blockchainService.sendMessageTransaction(
                    toAddress: identity.blockchainAddress,
                    encryptedMessage: jsonString,
                    messageType: "companion_identity"
                )
                
                await MainActor.run {
                    completion(response.success)
                }
            }
        } else {
            completion(false)
        }
    }
    
    /// Sets up blockchain integration and monitoring
    private func setupBlockchainIntegration() {
        // Monitor blockchain for companion-related transactions
        blockchainService.$recentTransactions
            .sink { [weak self] transactions in
                self?.processCompanionTransactions(transactions)
            }
            .store(in: &cancellables)
    }
    
    /// Processes blockchain transactions related to companion
    private func processCompanionTransactions(_ transactions: [TLSTransaction]) {
        for transaction in transactions {
            if transaction.messageType == "companion_update" || 
               transaction.messageType == "companion_message" {
                handleCompanionTransaction(transaction)
            }
        }
    }
    
    /// Handles companion-specific blockchain transactions
    private func handleCompanionTransaction(_ transaction: TLSTransaction) {
        guard let message = transaction.message else { return }
        
        // Decrypt and process companion message
        if let decryptedMessage = decryptCompanionMessage(message) {
            processCompanionMessage(decryptedMessage)
        }
    }
    
    // MARK: - Memory System
    
    /// Adds conversation memory entry
    func addConversationMemory(
        userInput: String,
        companionResponse: String,
        context: [String: Any] = [:],
        emotionalContext: ConversationMemory.EmotionalContext = .neutral,
        actionTaken: String? = nil,
        userFeedback: ConversationMemory.UserFeedback? = nil
    ) {
        let memory = ConversationMemory(
            id: UUID().uuidString,
            timestamp: Date(),
            userInput: userInput,
            companionResponse: companionResponse,
            context: context,
            emotionalContext: emotionalContext,
            actionTaken: actionTaken,
            userFeedback: userFeedback
        )
        
        conversationHistory.append(memory)
        saveConversationHistory()
        updateLearningData(memory)
    }
    
    /// Loads conversation history from storage
    private func loadConversationHistory() {
        if let historyData = keychainService.read(key: "conversation_history"),
           let data = historyData.data(using: .utf8),
           let history = try? JSONDecoder().decode([ConversationMemory].self, from: data) {
            conversationHistory = history
        }
    }
    
    /// Saves conversation history to storage
    private func saveConversationHistory() {
        if let data = try? JSONEncoder().encode(conversationHistory),
           let jsonString = String(data: data, encoding: .utf8) {
            _ = keychainService.save(key: "conversation_history", value: jsonString)
        }
    }
    
    /// Updates learning data based on conversation memory
    private func updateLearningData(_ memory: ConversationMemory) {
        guard var preferences = userPreferences else { return }
        
        // Update interaction patterns
        let timeKey = formatTimeKey(memory.timestamp)
        preferences.learningData.interactionPatterns[timeKey, default: 0] += 1
        
        // Update topic engagement
        let topics = extractTopics(from: memory.userInput)
        for topic in topics {
            preferences.learningData.topicEngagement[topic, default: 0.0] += 0.1
        }
        
        // Update response effectiveness based on feedback
        if let feedback = memory.userFeedback {
            let effectiveness = feedback == .positive ? 1.0 : (feedback == .negative ? -1.0 : 0.0)
            preferences.learningData.responseEffectiveness[memory.companionResponse, default: 0.0] += effectiveness
        }
        
        userPreferences = preferences
        saveCompanionData()
    }
    
    // MARK: - Response Generation
    
    /// Generates personalized response based on user input and context
    func generateResponse(to input: String, context: [String: Any] = [:]) -> String {
        guard let personality = currentPersonality else {
            return "I'm not properly configured yet. Please set up my personality first."
        }
        
        let contextualInput = buildContextualInput(input: input, context: context)
        let personalityPrompt = buildPersonalityPrompt(personality: personality)
        let memoryContext = buildMemoryContext()
        
        let fullPrompt = """
        \(personalityPrompt)
        
        Context from previous conversations:
        \(memoryContext)
        
        Current context:
        \(contextualInput)
        
        User input: \(input)
        
        Generate a response that matches my personality and considers the user's preferences and conversation history.
        """
        
        // In a real implementation, this would call the AI model
        return generateAIResponse(prompt: fullPrompt, personality: personality)
    }
    
    /// Builds contextual input with user preferences and current state
    private func buildContextualInput(input: String, context: [String: Any]) -> String {
        var contextualInput = "User input: \(input)\n"
        
        if let preferences = userPreferences {
            contextualInput += "User preferences:\n"
            contextualInput += "- Communication style: \(preferences.communicationStyle.rawValue)\n"
            contextualInput += "- Response length: \(preferences.responseLength.rawValue)\n"
            contextualInput += "- Preferred topics: \(preferences.preferredTopics.joined(separator: ", "))\n"
        }
        
        for (key, value) in context {
            contextualInput += "- \(key): \(value)\n"
        }
        
        return contextualInput
    }
    
    /// Builds personality prompt for AI response generation
    private func buildPersonalityPrompt(personality: CompanionPersonality) -> String {
        return """
        You are \(personality.name), a personalized AI companion with the following characteristics:
        
        Communication Style: \(personality.communicationStyle.rawValue)
        Expertise Areas: \(personality.expertiseAreas.map { $0.rawValue }.joined(separator: ", "))
        Emotional Tone: \(personality.emotionalTone.rawValue)
        Response Length: \(personality.responseLength.rawValue)
        
        Description: \(personality.description)
        
        Custom Traits:
        \(personality.customTraits.map { "- \($0.key): \($0.value)" }.joined(separator: "\n"))
        
        Always respond in a way that matches these characteristics and adapts to the user's needs.
        """
    }
    
    /// Builds memory context from conversation history
    private func buildMemoryContext() -> String {
        let recentMemories = conversationHistory.suffix(5)
        var context = ""
        
        for memory in recentMemories {
            context += "Previous exchange:\n"
            context += "User: \(memory.userInput)\n"
            context += "You: \(memory.companionResponse)\n"
            if let feedback = memory.userFeedback {
                context += "User feedback: \(feedback.rawValue)\n"
            }
            context += "\n"
        }
        
        return context
    }
    
    /// Generates AI response using the specified model
    private func generateAIResponse(prompt: String, personality: CompanionPersonality) -> String {
        // In a real implementation, this would call Grok or another AI model
        // For now, we'll generate a contextual response
        
        let responses = [
            "I understand you're asking about that. Let me help you with that.",
            "That's an interesting question! Based on our conversation history, I think...",
            "I appreciate you sharing that with me. Here's what I think...",
            "That reminds me of our previous discussion about...",
            "I'm here to help with that. Let me provide some guidance..."
        ]
        
        let baseResponse = responses.randomElement() ?? "I'm here to help!"
        
        // Adapt response based on personality
        switch personality.communicationStyle {
        case .formal:
            return "I appreciate your inquiry. \(baseResponse)"
        case .casual:
            return "Hey! \(baseResponse)"
        case .technical:
            return "From a technical perspective, \(baseResponse)"
        case .creative:
            return "That's such an interesting thought! \(baseResponse)"
        case .friendly:
            return "Thanks for asking! \(baseResponse)"
        case .professional:
            return "I'd be happy to assist with that. \(baseResponse)"
        }
    }
    
    // MARK: - Utility Methods
    
    /// Generates a public key for companion identity
    private func generatePublicKey() -> String {
        let privateKey = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let hash = SHA256.hash(data: privateKey)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Generates identity hash for companion
    private func generateIdentityHash(companionId: String, owner: String) -> String {
        let combined = companionId + owner + Date().timeIntervalSince1970.description
        let data = combined.data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Generates blockchain address for companion
    private func generateBlockchainAddress() -> String {
        let randomBytes = Data((0..<20).map { _ in UInt8.random(in: 0...255) })
        let hash = SHA256.hash(data: randomBytes)
        return "TLS" + hash.prefix(32).compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Formats time key for learning data
    private func formatTimeKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH"
        return formatter.string(from: date)
    }
    
    /// Extracts topics from user input
    private func extractTopics(from input: String) -> [String] {
        let topics = ["finance", "technology", "health", "creativity", "education", "entertainment", "business", "personal"]
        return topics.filter { input.lowercased().contains($0) }
    }
    
    /// Decrypts companion message from blockchain
    private func decryptCompanionMessage(_ encryptedMessage: String) -> String? {
        // In a real implementation, this would decrypt the message
        // For now, we'll assume it's base64 encoded
        guard let data = Data(base64Encoded: encryptedMessage),
              let decrypted = String(data: data, encoding: .utf8) else {
            return nil
        }
        return decrypted
    }
    
    /// Processes companion message from blockchain
    private func processCompanionMessage(_ message: String) {
        // Handle different types of companion messages
        if message.contains("personality_update") {
            handlePersonalityUpdate(message)
        } else if message.contains("preference_update") {
            handlePreferenceUpdate(message)
        }
    }
    
    /// Handles personality updates from blockchain
    private func handlePersonalityUpdate(_ message: String) {
        // Parse and apply personality updates
        print("Processing personality update: \(message)")
    }
    
    /// Handles preference updates from blockchain
    private func handlePreferenceUpdate(_ message: String) {
        // Parse and apply preference updates
        print("Processing preference update: \(message)")
    }
}

// MARK: - Companion Marketplace

/// Represents a companion template available in the marketplace
struct CompanionTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let creator: String
    let price: Double
    let personality: CompanionPersonality
    let tags: [String]
    let rating: Double
    let downloadCount: Int
    let isVerified: Bool
}

/// Manages companion marketplace functionality
class CompanionMarketplace: ObservableObject {
    @Published var availableTemplates: [CompanionTemplate] = []
    @Published var userCompanions: [CompanionTemplate] = []
    
    func loadTemplates() {
        // Load available companion templates
        // In a real implementation, this would fetch from blockchain or API
    }
    
    func purchaseTemplate(_ template: CompanionTemplate, completion: @escaping (Bool) -> Void) {
        // Purchase companion template using TLS tokens
        // In a real implementation, this would create a blockchain transaction
    }
    
    func publishTemplate(_ template: CompanionTemplate, completion: @escaping (Bool) -> Void) {
        // Publish companion template to marketplace
        // In a real implementation, this would store on blockchain
    }
} 