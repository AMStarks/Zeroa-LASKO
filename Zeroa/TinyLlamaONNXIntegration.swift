import Foundation
import AVFoundation

class TinyLlamaONNXIntegration: NSObject, ObservableObject {
    @Published var isGenerating = false
    @Published var isVoiceEnabled = false
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let maxHistoryLength = 10
    
    // Enhanced memory system
    private var currentCompanionId: String = "nova_default"
    private var companionMemory: CompanionMemory?
    private let memoryManager = MemoryManager.shared
    
    // User preferences
    @Published var userPreferences = UserPreferences()
    
    override init() {
        super.init()
        speechSynthesizer.delegate = self
        loadUserPreferences()
        initializeCompanionMemory()
    }
    
    private func initializeCompanionMemory() {
        // Try to load existing memory for this companion
        if let existingMemory = memoryManager.loadCompanionMemory(companionId: currentCompanionId) {
            companionMemory = existingMemory
            print("🧠 Loaded existing memory for companion: \(currentCompanionId)")
        } else {
            // Create new memory for this companion
            companionMemory = memoryManager.createCompanionMemory(
                companionId: currentCompanionId,
                userPreferences: userPreferences
            )
            print("🧠 Created new memory for companion: \(currentCompanionId)")
        }
    }
    
    private func loadUserPreferences() {
        userPreferences.name = UserDefaults.standard.string(forKey: "nova_user_name") ?? "User"
        userPreferences.interests = UserDefaults.standard.array(forKey: "nova_user_interests") as? [String] ?? ["technology", "crypto", "faith"]
        userPreferences.conversationStyle = UserDefaults.standard.string(forKey: "nova_conversation_style") ?? "supportive"
        
        print("👤 Loaded user preferences for: \(userPreferences.name)")
    }
    
    func sendMessage(_ message: String, completion: @escaping (String) -> Void) {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion("")
            return
        }
        
        isGenerating = true
        
        // Add user message to memory
        let userMessage = ConversationMessage(
            content: message,
            isUser: true,
            timestamp: Date()
        )
        addToMemory(userMessage)
        
        // Get enhanced context including memory insights
        let context = getEnhancedContext()
        
        // Make request to server
        makeAIRequest(message: message, context: context) { [weak self] response in
            DispatchQueue.main.async {
                self?.isGenerating = false
                
                // Add AI response to memory
                let aiMessage = ConversationMessage(
                    content: response,
                    isUser: false,
                    timestamp: Date()
                )
                self?.addToMemory(aiMessage)
                
                completion(response)
            }
        }
    }
    
    private func addToMemory(_ message: ConversationMessage) {
        guard var memory = companionMemory else { return }
        
        // Update memory with new message
        memoryManager.updateCompanionMemory(memory, newMessage: message)
        
        // Update local reference
        companionMemory = memoryManager.loadCompanionMemory(companionId: currentCompanionId)
        
        print("🧠 Added to memory: \(message.isUser ? "User" : "Nova") - \(message.content.prefix(50))...")
    }
    
    private func getEnhancedContext() -> [String: Any] {
        guard let memory = companionMemory else {
            return getBasicContext()
        }
        
        // Get recent messages (full conversation context up to 200 messages)
        let recentMessages = memory.conversationHistory.suffix(200).map { message in
            [
                "content": message.content,
                "is_user": message.isUser,
                "timestamp": message.timestamp.timeIntervalSince1970
            ]
        }
        
        // Get adaptive personality insights
        let adaptivePersonality = memoryManager.getAdaptivePersonality(companionId: currentCompanionId)
        
        // Get learning insights
        let insights = memoryManager.getCompanionInsights(companionId: currentCompanionId) ?? [:]
        
        // Get overflow memory if needed for context
        let overflowMessages = memoryManager.loadOverflowMemory(companionId: currentCompanionId)
        let overflowContext = overflowMessages?.suffix(20).map { message in
            [
                "content": message.content,
                "is_user": message.isUser,
                "timestamp": message.timestamp.timeIntervalSince1970
            ]
        } ?? []
        
        // Get conversation session insights
        let recentSessions = memory.conversationSessions.suffix(3)
        let sessionInsights = recentSessions.map { session in
            [
                "session_id": session.sessionId,
                "duration": session.duration,
                "message_count": session.messageCount,
                "emotional_tone": session.emotionalTone,
                "key_topics": session.keyTopics
            ]
        }
        
        return [
            "recent_messages": recentMessages,
            "overflow_context": overflowContext,
            "user_name": memory.userPreferences.name,
            "user_interests": memory.userPreferences.interests,
            "conversation_style": memory.userPreferences.conversationStyle,
            "learning_insights": insights,
            "adaptive_personality": adaptivePersonality,
            "conversation_sessions": sessionInsights,
            "companion_id": currentCompanionId,
            "memory_size": memory.memorySize,
            "days_active": insights["days_active"] as? Int ?? 0,
            "bonding_strength": adaptivePersonality["bonding_strength"] as? Double ?? 0.0
        ]
    }
    
    private func getBasicContext() -> [String: Any] {
        return [
            "recent_messages": [],
            "user_name": userPreferences.name,
            "user_interests": userPreferences.interests,
            "conversation_style": userPreferences.conversationStyle
        ]
    }
    
    private func makeAIRequest(message: String, context: [String: Any], completion: @escaping (String) -> Void) {
        guard let url = URL(string: "http://localhost:5001/chat") else {
            completion("Error: Invalid server URL")
            return
        }
        
        // Convert Date objects to ISO8601 strings for JSON serialization
        let jsonSafeContext = convertDatesToISO8601(context)
        
        // Prepare request data with enhanced context
        let requestData: [String: Any] = [
            "message": message,
            "user_name": context["user_name"] as? String ?? "User",
            "context": jsonSafeContext
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
        } catch {
            completion("Error: Failed to prepare request")
            return
        }
        
        print("🤖 Making AI request with enhanced memory context...")
        print("📊 Context includes: \(context["memory_size"] as? Int ?? 0) messages, \(context["days_active"] as? Int ?? 0) days active")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Server request failed: \(error)")
                completion("Error: Server connection failed - \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                completion("Error: No response from server")
                return
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let response = jsonResponse["response"] as? String {
                    print("✅ AI response received: \(response.prefix(50))...")
                    completion(response)
                } else {
                    // Try to parse as plain text
                    if let textResponse = String(data: data, encoding: .utf8) {
                        print("✅ AI response received: \(textResponse.prefix(50))...")
                        completion(textResponse)
                    } else {
                        completion("Error: Invalid response format from server")
                    }
                }
            } catch {
                completion("Error: Failed to parse server response")
            }
        }.resume()
    }
    
    // Helper function to convert Date objects to ISO8601 strings for JSON serialization
    private func convertDatesToISO8601(_ dict: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        let dateFormatter = ISO8601DateFormatter()
        
        for (key, value) in dict {
            if let date = value as? Date {
                result[key] = dateFormatter.string(from: date)
            } else if let nestedDict = value as? [String: Any] {
                result[key] = convertDatesToISO8601(nestedDict)
            } else if let array = value as? [Any] {
                result[key] = array.map { item -> Any in
                    if let date = item as? Date {
                        return dateFormatter.string(from: date)
                    } else if let nestedDict = item as? [String: Any] {
                        return convertDatesToISO8601(nestedDict)
                    }
                    return item
                }
            } else {
                result[key] = value
            }
        }
        
        return result
    }
    
    private func speakResponse(_ response: String) {
        let utterance = AVSpeechUtterance(string: response)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.8
        
        speechSynthesizer.speak(utterance)
        print("🎤 Speaking: \(response.prefix(50))...")
    }
    
    func toggleVoice() {
        isVoiceEnabled.toggle()
        print("🎤 Voice \(isVoiceEnabled ? "enabled" : "disabled")")
    }
    
    // Enhanced user preferences with memory integration
    func updateUserPreferences(name: String, interests: [String], conversationStyle: String) {
        userPreferences.name = name
        userPreferences.interests = interests
        userPreferences.conversationStyle = conversationStyle
        
        // Save to UserDefaults
        UserDefaults.standard.set(name, forKey: "nova_user_name")
        UserDefaults.standard.set(interests, forKey: "nova_user_interests")
        UserDefaults.standard.set(conversationStyle, forKey: "nova_conversation_style")
        
        // Update companion memory with new preferences
        if var memory = companionMemory {
            memory.userPreferences = userPreferences
            memoryManager.saveCompanionMemory(memory)
        }
        
        print("👤 Updated user preferences for: \(name)")
    }
    
    // Get companion insights
    func getCompanionInsights() -> [String: Any]? {
        return memoryManager.getCompanionInsights(companionId: currentCompanionId)
    }
    
    // Switch to different companion
    func switchCompanion(companionId: String) {
        currentCompanionId = companionId
        initializeCompanionMemory()
        print("🔄 Switched to companion: \(companionId)")
    }
}

// Memory & Context structures
struct ConversationMessage: Codable {
    let content: String
    let isUser: Bool
    let timestamp: Date
}

// User preferences structure
struct UserPreferences: Codable {
    var name: String = "User"
    var interests: [String] = ["technology", "crypto", "faith"]
    var conversationStyle: String = "supportive"
}

// Enhanced memory system for AI companions
struct CompanionMemory: Codable {
    let companionId: String
    var conversationHistory: [ConversationMessage]
    var userPreferences: UserPreferences
    var learningPatterns: [String: Int] // Track topics/interests
    var emotionalContext: [String: String] // Track emotional states
    var conversationSessions: [ConversationSession] // Store complete conversation sessions
    let createdAt: Date
    var lastInteraction: Date
    
    // Memory management
    var memorySize: Int {
        return conversationHistory.count
    }
    
    var needsOverflow: Bool {
        return conversationHistory.count > 200 // Increased for full conversations
    }
}

// Conversation session for banking complete conversations
struct ConversationSession: Codable {
    let sessionId: String
    let startTime: Date
    let endTime: Date
    let messages: [ConversationMessage]
    let userInterests: [String]
    let conversationStyle: String
    let emotionalTone: String
    let keyTopics: [String]
    
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    var messageCount: Int {
        return messages.count
    }
}

// Memory manager for persistent storage
class MemoryManager {
    static let shared = MemoryManager()
    private let fileManager = FileManager.default
    
    private var companionsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("AICompanions")
    }
    
    private init() {
        createCompanionsDirectory()
    }
    
    private func createCompanionsDirectory() {
        if !fileManager.fileExists(atPath: companionsDirectory.path) {
            try? fileManager.createDirectory(at: companionsDirectory, withIntermediateDirectories: true)
        }
    }
    
    // Save companion memory to local storage
    func saveCompanionMemory(_ memory: CompanionMemory) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(memory)
            let fileURL = companionsDirectory.appendingPathComponent("\(memory.companionId).json")
            try data.write(to: fileURL)
            print("💾 Saved memory for companion: \(memory.companionId)")
        } catch {
            print("❌ Failed to save memory: \(error)")
        }
    }
    
    // Load companion memory from local storage
    func loadCompanionMemory(companionId: String) -> CompanionMemory? {
        let fileURL = companionsDirectory.appendingPathComponent("\(companionId).json")
        
        guard let data = try? Data(contentsOf: fileURL) else {
            print("📂 No existing memory found for companion: \(companionId)")
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let memory = try decoder.decode(CompanionMemory.self, from: data)
            print("📂 Loaded memory for companion: \(companionId) with \(memory.conversationHistory.count) messages")
            return memory
        } catch {
            print("❌ Failed to load memory: \(error)")
            return nil
        }
    }
    
    // Create new companion memory
    func createCompanionMemory(companionId: String, userPreferences: UserPreferences) -> CompanionMemory {
        let memory = CompanionMemory(
            companionId: companionId,
            conversationHistory: [],
            userPreferences: userPreferences,
            learningPatterns: [:],
            emotionalContext: [:],
            conversationSessions: [], // Initialize empty
            createdAt: Date(),
            lastInteraction: Date()
        )
        saveCompanionMemory(memory)
        return memory
    }
    
    // Update companion memory with new interaction
    func updateCompanionMemory(_ memory: CompanionMemory, newMessage: ConversationMessage) {
        var updatedMemory = memory
        updatedMemory.conversationHistory.append(newMessage)
        updatedMemory.lastInteraction = Date()
        
        // Update learning patterns based on message content
        let words = newMessage.content.lowercased().components(separatedBy: .whitespacesAndNewlines)
        for word in words {
            if word.count > 3 { // Only track meaningful words
                updatedMemory.learningPatterns[word, default: 0] += 1
            }
        }
        
        // Keep full conversation context during active sessions (up to 200 messages)
        if updatedMemory.conversationHistory.count > 200 {
            // Bank the current conversation session
            let sessionMessages = updatedMemory.conversationHistory
            let session = createConversationSession(from: sessionMessages, userPreferences: memory.userPreferences)
            updatedMemory.conversationSessions.append(session)
            
            // Keep only last 50 messages for active context
            updatedMemory.conversationHistory = Array(updatedMemory.conversationHistory.suffix(50))
            
            // Store overflow in separate file
            saveOverflowMemory(companionId: memory.companionId, messages: sessionMessages)
        }
        
        saveCompanionMemory(updatedMemory)
    }
    
    // Create conversation session from messages
    private func createConversationSession(from messages: [ConversationMessage], userPreferences: UserPreferences) -> ConversationSession {
        let sessionId = UUID().uuidString
        let startTime = messages.first?.timestamp ?? Date()
        let endTime = messages.last?.timestamp ?? Date()
        
        // Extract key topics from conversation
        let allText = messages.map { $0.content }.joined(separator: " ").lowercased()
        let words = allText.components(separatedBy: .whitespacesAndNewlines)
        let wordFrequency = Dictionary(grouping: words.filter { $0.count > 3 }, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        let keyTopics = Array(wordFrequency.prefix(10).map { $0.key })
        
        // Determine emotional tone
        let emotionalTone = analyzeEmotionalTone(messages: messages)
        
        return ConversationSession(
            sessionId: sessionId,
            startTime: startTime,
            endTime: endTime,
            messages: messages,
            userInterests: userPreferences.interests,
            conversationStyle: userPreferences.conversationStyle,
            emotionalTone: emotionalTone,
            keyTopics: keyTopics
        )
    }
    
    // Analyze emotional tone of conversation
    private func analyzeEmotionalTone(messages: [ConversationMessage]) -> String {
        let allText = messages.map { $0.content }.joined(separator: " ").lowercased()
        
        let positiveWords = ["happy", "great", "awesome", "love", "excited", "wonderful", "amazing", "good", "nice", "beautiful"]
        let negativeWords = ["sad", "angry", "frustrated", "upset", "worried", "anxious", "bad", "terrible", "awful", "hate"]
        let analyticalWords = ["think", "analyze", "consider", "understand", "explain", "discuss", "reason", "logic"]
        
        var positiveCount = 0
        var negativeCount = 0
        var analyticalCount = 0
        
        for word in allText.components(separatedBy: .whitespacesAndNewlines) {
            if positiveWords.contains(word) { positiveCount += 1 }
            if negativeWords.contains(word) { negativeCount += 1 }
            if analyticalWords.contains(word) { analyticalCount += 1 }
        }
        
        if positiveCount > negativeCount && positiveCount > analyticalCount {
            return "positive"
        } else if negativeCount > positiveCount && negativeCount > analyticalCount {
            return "negative"
        } else if analyticalCount > positiveCount && analyticalCount > negativeCount {
            return "analytical"
        } else {
            return "neutral"
        }
    }
    
    // Get adaptive personality based on user interactions
    func getAdaptivePersonality(companionId: String) -> [String: Any] {
        guard let memory = loadCompanionMemory(companionId: companionId) else {
            return [:]
        }
        
        // Analyze user's top interests (85% influence)
        let userTopInterests = memory.learningPatterns.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
        
        // Nova's core interests (15% influence)
        let novaCoreInterests = ["faith", "wisdom", "compassion", "technology", "growth"]
        
        // Create adaptive personality blend
        let adaptiveInterests = userTopInterests + novaCoreInterests.prefix(2)
        
        // Analyze conversation patterns
        let totalSessions = memory.conversationSessions.count
        let averageSessionLength = memory.conversationSessions.map { $0.messageCount }.reduce(0, +) / max(totalSessions, 1)
        let preferredEmotionalTone = memory.conversationSessions.map { $0.emotionalTone }.mostFrequent() ?? "neutral"
        
        return [
            "adaptive_interests": Array(adaptiveInterests),
            "user_influence": 0.85,
            "nova_core": 0.15,
            "total_conversations": totalSessions,
            "average_session_length": averageSessionLength,
            "preferred_emotional_tone": preferredEmotionalTone,
            "conversation_style": memory.userPreferences.conversationStyle,
            "bonding_strength": calculateBondingStrength(memory: memory)
        ]
    }
    
    // Calculate bonding strength based on interaction patterns
    private func calculateBondingStrength(memory: CompanionMemory) -> Double {
        let daysActive = Calendar.current.dateComponents([.day], from: memory.createdAt, to: Date()).day ?? 1
        let totalInteractions = memory.conversationHistory.count
        let sessionCount = memory.conversationSessions.count
        
        // Bonding increases with regular interaction and longer sessions
        let interactionFrequency = Double(totalInteractions) / Double(daysActive)
        let sessionQuality = Double(sessionCount) / Double(max(daysActive, 1))
        
        let bondingScore = min((interactionFrequency * 0.6 + sessionQuality * 0.4) * 10, 1.0)
        return bondingScore
    }
    
    // Save overflow messages to external storage
    private func saveOverflowMemory(companionId: String, messages: [ConversationMessage]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(messages)
            let overflowURL = companionsDirectory.appendingPathComponent("\(companionId)_overflow.json")
            try data.write(to: overflowURL)
            print("💾 Saved overflow memory for companion: \(companionId) with \(messages.count) messages")
        } catch {
            print("❌ Failed to save overflow memory: \(error)")
        }
    }
    
    // Load overflow memory when needed
    func loadOverflowMemory(companionId: String) -> [ConversationMessage]? {
        let overflowURL = companionsDirectory.appendingPathComponent("\(companionId)_overflow.json")
        
        guard let data = try? Data(contentsOf: overflowURL) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let messages = try decoder.decode([ConversationMessage].self, from: data)
            print("📂 Loaded overflow memory for companion: \(companionId) with \(messages.count) messages")
            return messages
        } catch {
            print("❌ Failed to load overflow memory: \(error)")
            return nil
        }
    }
    
    // Get companion's learning insights
    func getCompanionInsights(companionId: String) -> [String: Any]? {
        guard let memory = loadCompanionMemory(companionId: companionId) else {
            return nil
        }
        
        let topInterests = memory.learningPatterns.sorted { $0.value > $1.value }.prefix(5)
        let totalInteractions = memory.conversationHistory.count
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: memory.createdAt, to: Date()).day ?? 0
        
        return [
            "top_interests": Array(topInterests.map { $0.key }),
            "total_interactions": totalInteractions,
            "days_active": daysSinceCreation,
            "last_interaction": memory.lastInteraction,
            "conversation_style": memory.userPreferences.conversationStyle
        ]
    }
}

// Voice synthesis delegate
extension TinyLlamaONNXIntegration: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🎤 Started speaking")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🎤 Finished speaking")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("🎤 Speech cancelled")
    }
}

// Extension for array utilities
extension Array where Element == String {
    func mostFrequent() -> String? {
        let frequency = Dictionary(grouping: self, by: { $0 })
            .mapValues { $0.count }
            .max { $0.value < $1.value }
        return frequency?.key
    }
} 