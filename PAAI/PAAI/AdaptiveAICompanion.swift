import Foundation
import CryptoKit
import Combine
import SwiftUI

// MARK: - Adaptive AI Companion Models

/// Represents an adaptive AI companion that learns and evolves
struct AdaptiveCompanion: Codable {
    let id: String
    let name: String
    let initialDescription: String
    var currentPersonality: AdaptivePersonality
    var learningData: CompanionLearningData
    var interventionPreferences: InterventionPreferences
    let creationDate: Date
    var lastInteractionDate: Date
    
    struct AdaptivePersonality: Codable {
        var communicationStyle: CommunicationStyle
        var interventionStyle: InterventionStyle
        var expertiseAreas: [ExpertiseArea]
        var emotionalTone: EmotionalTone
        var responseLength: ResponseLength
        var customTraits: [String: String]
        var learningRate: Double // How quickly the companion adapts
        
        enum CommunicationStyle: String, Codable, CaseIterable {
            case formal = "formal"
            case casual = "casual"
            case technical = "technical"
            case creative = "creative"
            case friendly = "friendly"
            case professional = "professional"
            case adaptive = "adaptive"
        }
        
        enum InterventionStyle: String, Codable, CaseIterable {
            case proactive = "proactive"
            case reactive = "reactive"
            case balanced = "balanced"
            case minimal = "minimal"
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
            case productivity = "productivity"
            case security = "security"
        }
        
        enum EmotionalTone: String, Codable, CaseIterable {
            case neutral = "neutral"
            case enthusiastic = "enthusiastic"
            case calm = "calm"
            case supportive = "supportive"
            case analytical = "analytical"
            case adaptive = "adaptive"
        }
        
        enum ResponseLength: String, Codable, CaseIterable {
            case concise = "concise"
            case detailed = "detailed"
            case adaptive = "adaptive"
        }
    }
    
    struct CompanionLearningData: Codable {
        var userBehaviorPatterns: [String: BehaviorPattern]
        var interactionHistory: [InteractionRecord]
        var topicEngagement: [String: Double]
        var interventionEffectiveness: [String: Double]
        var userPreferences: [String: Double]
        var contextUnderstanding: [String: ContextData]
        
        struct BehaviorPattern: Codable {
            let pattern: String
            var frequency: Int
            var lastObserved: Date
            var context: [String: String]
            var userResponse: UserResponse?
            
            enum UserResponse: String, Codable {
                case positive = "positive"
                case negative = "negative"
                case neutral = "neutral"
                case ignored = "ignored"
            }
        }
        
        struct InteractionRecord: Codable {
            let id: String
            let timestamp: Date
            let userAction: String
            let companionResponse: String?
            let context: [String: String]
            let userFeedback: UserFeedback?
            let interventionType: InterventionType?
            
            enum UserFeedback: String, Codable {
                case helpful = "helpful"
                case annoying = "annoying"
                case neutral = "neutral"
                case ignored = "ignored"
            }
            
            enum InterventionType: String, Codable {
                case suggestion = "suggestion"
                case warning = "warning"
                case alternative = "alternative"
                case optimization = "optimization"
                case security = "security"
            }
        }
        
        struct ContextData: Codable {
            let context: String
            var understanding: Double
            var lastUpdated: Date
            var relatedPatterns: [String]
        }
    }
    
    struct InterventionPreferences: Codable {
        var allowProactiveInterventions: Bool
        var interventionFrequency: InterventionFrequency
        var preferredInterventionTypes: [CompanionLearningData.InteractionRecord.InterventionType]
        var quietHours: [String: Bool] // Hour of day -> whether to intervene
        var contextSensitivity: Double // 0.0 to 1.0
        
        enum InterventionFrequency: String, Codable, CaseIterable {
            case high = "high"
            case medium = "medium"
            case low = "low"
            case adaptive = "adaptive"
        }
    }
}

/// Represents a user action being monitored
struct UserAction: Codable {
    let id: String
    let timestamp: Date
    let actionType: ActionType
    let context: [String: String]
    let appContext: AppContext?
    let userIntent: String?
    
    enum ActionType: String, Codable {
        case navigation = "navigation"
        case dataEntry = "data_entry"
        case transaction = "transaction"
        case search = "search"
        case setting = "setting"
        case communication = "communication"
        case security = "security"
        case productivity = "productivity"
    }
    
    struct AppContext: Codable {
        let appName: String
        let screenName: String?
        let currentView: String?
        let userData: [String: String]?
    }
}

/// Represents a proactive intervention by the AI companion
struct ProactiveIntervention: Codable {
    let id: String
    let timestamp: Date
    let interventionType: CompanionLearningData.InteractionRecord.InterventionType
    let message: String
    let context: [String: String]
    let urgency: Urgency
    let suggestedActions: [String]?
    let userResponse: UserResponse?
    
    enum Urgency: String, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
    }
    
    enum UserResponse: String, Codable {
        case accepted = "accepted"
        case dismissed = "dismissed"
        case ignored = "ignored"
        case feedback = "feedback"
    }
}

// MARK: - Adaptive AI Companion Service

/// Main adaptive AI companion service that learns and provides proactive interventions
class AdaptiveAICompanion: ObservableObject {
    static let shared = AdaptiveAICompanion()
    
    @Published var currentCompanion: AdaptiveCompanion?
    @Published var isActive = false
    @Published var isMonitoring = false
    @Published var recentInterventions: [ProactiveIntervention] = []
    @Published var currentContext: [String: Any] = [:]
    
    private let walletService = WalletService.shared
    private let blockchainService = TLSBlockchainService.shared
    private let keychainService = KeychainService.shared
    private var cancellables = Set<AnyCancellable>()
    private var actionMonitor: ActionMonitor?
    
    // MARK: - Initialization
    
    init() {
        loadCompanionData()
        setupActionMonitoring()
    }
    
    // MARK: - Companion Management
    
    /// Creates a new adaptive AI companion with minimal setup
    func createAdaptiveCompanion(
        name: String,
        description: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard let userAddress = walletService.loadAddress() else {
            completion(false, "No wallet address found")
            return
        }
        
        let companionId = UUID().uuidString
        
        let initialPersonality = AdaptiveCompanion.AdaptivePersonality(
            communicationStyle: .adaptive,
            interventionStyle: .balanced,
            expertiseAreas: [.productivity, .technology, .personal],
            emotionalTone: .adaptive,
            responseLength: .adaptive,
            customTraits: [:],
            learningRate: 0.1
        )
        
        let learningData = AdaptiveCompanion.CompanionLearningData(
            userBehaviorPatterns: [:],
            interactionHistory: [],
            topicEngagement: [:],
            interventionEffectiveness: [:],
            userPreferences: [:],
            contextUnderstanding: [:]
        )
        
        let interventionPreferences = AdaptiveCompanion.InterventionPreferences(
            allowProactiveInterventions: true,
            interventionFrequency: .adaptive,
            preferredInterventionTypes: [.suggestion, .optimization],
            quietHours: [:],
            contextSensitivity: 0.7
        )
        
        let companion = AdaptiveCompanion(
            id: companionId,
            name: name,
            initialDescription: description,
            currentPersonality: initialPersonality,
            learningData: learningData,
            interventionPreferences: interventionPreferences,
            creationDate: Date(),
            lastInteractionDate: Date()
        )
        
        // Create blockchain identity
        createBlockchainIdentity(for: companionId, owner: userAddress) { [weak self] success, identity in
            if success {
                self?.currentCompanion = companion
                self?.saveCompanionData()
                self?.startMonitoring()
                completion(true, companionId)
            } else {
                completion(false, "Failed to create blockchain identity")
            }
        }
    }
    
    /// Loads existing companion data
    private func loadCompanionData() {
        if let companionData = keychainService.read(key: "adaptive_companion"),
           let data = companionData.data(using: .utf8),
           let companion = try? JSONDecoder().decode(AdaptiveCompanion.self, from: data) {
            currentCompanion = companion
        }
    }
    
    /// Saves companion data to secure storage
    private func saveCompanionData() {
        if let companion = currentCompanion,
           let data = try? JSONEncoder().encode(companion),
           let jsonString = String(data: data, encoding: .utf8) {
            _ = keychainService.save(key: "adaptive_companion", value: jsonString)
        }
    }
    
    // MARK: - Action Monitoring
    
    /// Sets up background action monitoring
    private func setupActionMonitoring() {
        actionMonitor = ActionMonitor()
        actionMonitor?.delegate = self
    }
    
    /// Starts monitoring user actions
    func startMonitoring() {
        isMonitoring = true
        actionMonitor?.startMonitoring()
    }
    
    /// Stops monitoring user actions
    func stopMonitoring() {
        isMonitoring = false
        actionMonitor?.stopMonitoring()
    }
    
    /// Records a user action for learning
    func recordUserAction(_ action: UserAction) {
        guard var companion = currentCompanion else { return }
        
        // Update learning data
        updateLearningData(with: action)
        
        // Check for potential interventions
        checkForInterventions(for: action)
        
        // Update companion
        companion.lastInteractionDate = Date()
        currentCompanion = companion
        saveCompanionData()
    }
    
    /// Updates learning data based on user action
    private func updateLearningData(with action: UserAction) {
        guard var companion = currentCompanion else { return }
        
        // Record interaction
        let interaction = AdaptiveCompanion.CompanionLearningData.InteractionRecord(
            id: UUID().uuidString,
            timestamp: action.timestamp,
            userAction: action.actionType.rawValue,
            companionResponse: nil,
            context: action.context,
            userFeedback: nil,
            interventionType: nil
        )
        
        companion.learningData.interactionHistory.append(interaction)
        
        // Update behavior patterns
        let patternKey = "\(action.actionType.rawValue)_\(action.context.values.joined())"
        if let existingPattern = companion.learningData.userBehaviorPatterns[patternKey] {
            companion.learningData.userBehaviorPatterns[patternKey] = AdaptiveCompanion.CompanionLearningData.BehaviorPattern(
                pattern: existingPattern.pattern,
                frequency: existingPattern.frequency + 1,
                lastObserved: action.timestamp,
                context: action.context,
                userResponse: existingPattern.userResponse
            )
        } else {
            companion.learningData.userBehaviorPatterns[patternKey] = AdaptiveCompanion.CompanionLearningData.BehaviorPattern(
                pattern: patternKey,
                frequency: 1,
                lastObserved: action.timestamp,
                context: action.context,
                userResponse: nil
            )
        }
        
        // Update topic engagement
        let topics = extractTopics(from: action)
        for topic in topics {
            companion.learningData.topicEngagement[topic, default: 0.0] += 0.1
        }
        
        currentCompanion = companion
    }
    
    /// Checks for potential interventions based on user action
    private func checkForInterventions(for action: UserAction) {
        guard let companion = currentCompanion,
              companion.interventionPreferences.allowProactiveInterventions else { return }
        
        // Analyze action for intervention opportunities
        let interventions = analyzeForInterventions(action: action, companion: companion)
        
        for intervention in interventions {
            if shouldIntervene(intervention: intervention, companion: companion) {
                presentIntervention(intervention)
            }
        }
    }
    
    /// Analyzes user action for potential interventions
    private func analyzeForInterventions(action: UserAction, companion: AdaptiveCompanion) -> [ProactiveIntervention] {
        var interventions: [ProactiveIntervention] = []
        
        // Check for security concerns
        if action.actionType == .transaction || action.actionType == .security {
            if let securityIntervention = checkSecurityIntervention(action: action) {
                interventions.append(securityIntervention)
            }
        }
        
        // Check for optimization opportunities
        if let optimizationIntervention = checkOptimizationIntervention(action: action, companion: companion) {
            interventions.append(optimizationIntervention)
        }
        
        // Check for alternative approaches
        if let alternativeIntervention = checkAlternativeIntervention(action: action, companion: companion) {
            interventions.append(alternativeIntervention)
        }
        
        return interventions
    }
    
    /// Checks for security-related interventions
    private func checkSecurityIntervention(action: UserAction) -> ProactiveIntervention? {
        // Example: Detect potential security risks
        if action.actionType == .transaction {
            return ProactiveIntervention(
                id: UUID().uuidString,
                timestamp: Date(),
                interventionType: .security,
                message: "I notice you're making a transaction. Would you like me to review the details for any potential security concerns?",
                context: action.context,
                urgency: .medium,
                suggestedActions: ["Review transaction details", "Check recipient address", "Verify amount"],
                userResponse: nil
            )
        }
        
        return nil
    }
    
    /// Checks for optimization opportunities
    private func checkOptimizationIntervention(action: UserAction, companion: AdaptiveCompanion) -> ProactiveIntervention? {
        // Analyze patterns for optimization opportunities
        let patternKey = "\(action.actionType.rawValue)_\(action.context.values.joined())"
        if let pattern = companion.learningData.userBehaviorPatterns[patternKey],
           pattern.frequency > 3 {
            return ProactiveIntervention(
                id: UUID().uuidString,
                timestamp: Date(),
                interventionType: .optimization,
                message: "I've noticed you do this frequently. Would you like me to suggest a more efficient way?",
                context: action.context,
                urgency: .low,
                suggestedActions: ["Show optimization tips", "Create shortcut", "Automate this action"],
                userResponse: nil
            )
        }
        
        return nil
    }
    
    /// Checks for alternative approaches
    private func checkAlternativeIntervention(action: UserAction, companion: AdaptiveCompanion) -> ProactiveIntervention? {
        // Suggest alternatives based on learned preferences
        if action.actionType == .navigation || action.actionType == .dataEntry {
            return ProactiveIntervention(
                id: UUID().uuidString,
                timestamp: Date(),
                interventionType: .alternative,
                message: "Based on your patterns, there might be a faster way to accomplish this. Would you like to know more?",
                context: action.context,
                urgency: .low,
                suggestedActions: ["Show alternative method", "Explain benefits", "Dismiss"],
                userResponse: nil
            )
        }
        
        return nil
    }
    
    /// Determines if intervention should be presented
    private func shouldIntervene(intervention: ProactiveIntervention, companion: AdaptiveCompanion) -> Bool {
        // Check intervention frequency preferences
        let recentInterventions = recentInterventions.filter { 
            $0.timestamp.timeIntervalSinceNow > -3600 // Last hour
        }
        
        switch companion.interventionPreferences.interventionFrequency {
        case .high:
            return true
        case .medium:
            return recentInterventions.count < 5
        case .low:
            return recentInterventions.count < 2
        case .adaptive:
            return recentInterventions.count < 3
        }
    }
    
    /// Presents an intervention to the user
    private func presentIntervention(_ intervention: ProactiveIntervention) {
        DispatchQueue.main.async {
            self.recentInterventions.append(intervention)
            // In a real implementation, this would show a notification or overlay
            print("Intervention: \(intervention.message)")
        }
    }
    
    /// Records user response to intervention
    func recordInterventionResponse(_ interventionId: String, response: ProactiveIntervention.UserResponse) {
        guard var companion = currentCompanion else { return }
        
        // Update intervention effectiveness
        companion.learningData.interventionEffectiveness[interventionId, default: 0.0] += 
            (response == .accepted ? 1.0 : (response == .dismissed ? -0.5 : 0.0))
        
        // Update behavior patterns
        if let intervention = recentInterventions.first(where: { $0.id == interventionId }) {
            let patternKey = "intervention_\(intervention.interventionType.rawValue)"
            if let existingPattern = companion.learningData.userBehaviorPatterns[patternKey] {
                companion.learningData.userBehaviorPatterns[patternKey] = AdaptiveCompanion.CompanionLearningData.BehaviorPattern(
                    pattern: existingPattern.pattern,
                    frequency: existingPattern.frequency + 1,
                    lastObserved: Date(),
                    context: intervention.context,
                    userResponse: .init(rawValue: response.rawValue)
                )
            }
        }
        
        currentCompanion = companion
        saveCompanionData()
    }
    
    // MARK: - Blockchain Integration
    
    /// Creates blockchain identity for companion
    private func createBlockchainIdentity(for companionId: String, owner: String, completion: @escaping (Bool, String?) -> Void) {
        let publicKey = generatePublicKey()
        let identityHash = generateIdentityHash(companionId: companionId, owner: owner)
        
        // Store identity on blockchain
        let identityData: [String: Any] = [
            "type": "adaptive_companion_identity",
            "companion_id": companionId,
            "public_key": publicKey,
            "identity_hash": identityHash,
            "owner": owner,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: identityData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            
            Task {
                let response = await blockchainService.sendMessageTransaction(
                    toAddress: generateBlockchainAddress(),
                    encryptedMessage: jsonString,
                    messageType: "adaptive_companion_identity"
                )
                
                await MainActor.run {
                    completion(response.success, response.success ? identityHash : nil)
                }
            }
        } else {
            completion(false, nil)
        }
    }
    
    // MARK: - Utility Methods
    
    /// Extracts topics from user action
    private func extractTopics(from action: UserAction) -> [String] {
        let topics = ["finance", "technology", "health", "creativity", "education", "entertainment", "business", "personal", "productivity", "security"]
        let actionString = "\(action.actionType.rawValue) \(action.context.values.joined())"
        return topics.filter { actionString.lowercased().contains($0) }
    }
    
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
}

// MARK: - Action Monitor

/// Monitors user actions in the background
class ActionMonitor: NSObject {
    weak var delegate: AdaptiveAICompanion?
    
    func startMonitoring() {
        // In a real implementation, this would use iOS APIs to monitor user actions
        // For now, we'll simulate monitoring
        print("Action monitoring started")
    }
    
    func stopMonitoring() {
        print("Action monitoring stopped")
    }
}

// MARK: - Adaptive AI Companion Delegate

extension AdaptiveAICompanion: ActionMonitorDelegate {
    func actionMonitor(_ monitor: ActionMonitor, didDetectAction action: UserAction) {
        recordUserAction(action)
    }
}

protocol ActionMonitorDelegate: AnyObject {
    func actionMonitor(_ monitor: ActionMonitor, didDetectAction action: UserAction)
} 