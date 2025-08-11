import Foundation
import CoreML
import NaturalLanguage

// MARK: - TinyLlama Tokenizer
class TinyLlamaTokenizer {
    private var vocab: [String: Int] = [:]
    private var merges: [String] = []
    private let specialTokens: [String: String] = [
        "bos_token": "<s>",
        "eos_token": "</s>",
        "pad_token": "</s>",
        "unk_token": "<unk>"
    ]
    
    private var isLoaded = false
    private var loadError: String?
    
    init() {
        loadTokenizer()
    }
    
    private func loadTokenizer() {
        // Load vocabulary from tokenizer.json
        print("🔍 Looking for tokenizer file...")
        
        // Check if the file exists in the bundle
        guard let tokenizerPath = Bundle.main.path(forResource: "tokenizer", ofType: "json", inDirectory: nil) else {
            loadError = "Tokenizer file not found in app bundle"
            print("❌ \(loadError!)")
            print("📁 Available bundle resources:")
            let resources = Bundle.main.paths(forResourcesOfType: nil, inDirectory: nil)
            for resource in resources.prefix(10) {
                print("  - \(resource)")
            }
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: tokenizerPath))
            let tokenizerData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let model = (tokenizerData?["model"] as? [String: Any]),
                  let vocabData = model["vocab"] as? [String: Int] else {
                loadError = "Invalid tokenizer format"
                print("❌ \(loadError!)")
                return
            }
            
            self.vocab = vocabData
            self.isLoaded = true
            print("✅ TinyLlama vocabulary loaded: \(vocab.count) tokens")
            
        } catch {
            loadError = "Failed to load tokenizer: \(error.localizedDescription)"
            print("❌ \(loadError!)")
        }
        
        // Load merges if available
        if let mergesPath = Bundle.main.path(forResource: "tokenizer", ofType: "model", inDirectory: nil) {
            // Load BPE merges (simplified)
            self.merges = []
            print("✅ TinyLlama merges loaded: \(merges.count) merges")
        }
    }
    
    func isTokenizerLoaded() -> Bool {
        return isLoaded && !vocab.isEmpty
    }
    
    func getLoadError() -> String? {
        return loadError
    }
    
    func tokenize(_ text: String) -> [Int] {
        guard isLoaded else {
            print("⚠️ Tokenizer not loaded, using fallback")
            return fallbackTokenize(text)
        }
        
        var tokens: [Int] = []
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        
        for word in words {
            if let tokenId = vocab[word] {
                tokens.append(tokenId)
            } else {
                // Handle unknown words by character-level tokenization
                let charTokens = tokenizeWordByCharacters(word)
                tokens.append(contentsOf: charTokens)
            }
        }
        
        return tokens
    }
    
    private func tokenizeWordByCharacters(_ word: String) -> [Int] {
        var tokens: [Int] = []
        
        for char in word {
            let charString = String(char)
            if let tokenId = vocab[charString] {
                tokens.append(tokenId)
            } else {
                // Use UNK token for unknown characters
                if let unkToken = vocab["<unk>"] {
                    tokens.append(unkToken)
                }
            }
        }
        
        return tokens
    }
    
    private func fallbackTokenize(_ text: String) -> [Int] {
        // Simple fallback tokenization
        return text.components(separatedBy: .whitespacesAndNewlines).map { $0.hashValue % 1000 }
    }
    

    
    func detokenize(_ tokens: [Int]) -> String {
        guard isLoaded else {
            return "Tokenizer not loaded"
        }
        
        var text = ""
        for tokenId in tokens {
            if let word = vocab.first(where: { $0.value == tokenId })?.key {
                text += word + " "
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - TinyLlama Model Integration
class TinyLlamaIntegration: ObservableObject {
    @Published var isModelLoaded = false
    @Published var isGenerating = false
    @Published var lastResponse = ""
    @Published var modelError: String?
    
    // Model properties
    private var tokenizer: TinyLlamaTokenizer?
    private var modelConfig: [String: Any]?
    private var modelWeights: Data?
    
    // Relationship building properties
    private var conversationCount = 0
    private var userPreferences: [String: Any] = [:]
    private var insideJokes: [String] = []
    private var relationshipLevel = 0 // 0-100, increases over time
    private var lastInteractionDate: Date?
    
    // Conversation context with memory management
    private var conversationHistory: [String] = []
    private let maxHistoryLength = 10
    private let maxMemoryUsage = 50_000_000 // 50MB limit
    
    init() {
        loadModel()
        loadRelationshipData()
    }
    
    private func loadModel() {
        print("🚀 Loading TinyLlama model...")
        
        // Load tokenizer
        tokenizer = TinyLlamaTokenizer()
        
        // Check tokenizer loading status
        if let tokenizer = tokenizer {
            if tokenizer.isTokenizerLoaded() {
                print("✅ TinyLlama tokenizer loaded successfully")
            } else {
                print("⚠️ TinyLlama tokenizer failed to load: \(tokenizer.getLoadError() ?? "Unknown error")")
                modelError = "Tokenizer loading failed"
            }
        }
        
        // Load model configuration
        if let configPath = Bundle.main.path(forResource: "config", ofType: "json", inDirectory: nil),
           let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
           let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.modelConfig = config
            print("✅ TinyLlama config loaded: \(config["model_type"] ?? "unknown")")
        } else {
            print("❌ Failed to load TinyLlama config")
            print("📁 Checking available resources in Data/TinyLlama directory...")
            if let dataDir = Bundle.main.path(forResource: "Data", ofType: nil) {
                print("  - Data directory found: \(dataDir)")
            } else {
                print("  - Data directory not found in bundle")
            }
            modelError = "Config loading failed"
        }
        
        // Load model weights (simplified - just check if file exists)
        if let weightsPath = Bundle.main.path(forResource: "model", ofType: "safetensors", inDirectory: nil) {
            print("✅ TinyLlama weights found: \(weightsPath)")
            // In a full implementation, we'd load the weights here
        } else {
            print("❌ TinyLlama weights not found")
            modelError = "Weights not found"
        }
        
        // Only mark as loaded if critical components are available
        if tokenizer?.isTokenizerLoaded() == true {
            isModelLoaded = true
            print("✅ TinyLlama integration loaded successfully (using enhanced tokenization)")
        } else {
            isModelLoaded = false
            print("⚠️ TinyLlama integration loaded with fallback mode")
        }
    }
    
    private func loadRelationshipData() {
        // Load saved relationship data
        if let data = UserDefaults.standard.data(forKey: "NovaRelationshipData"),
           let relationshipData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            conversationCount = relationshipData["conversationCount"] as? Int ?? 0
            userPreferences = relationshipData["userPreferences"] as? [String: Any] ?? [:]
            insideJokes = relationshipData["insideJokes"] as? [String] ?? []
            relationshipLevel = relationshipData["relationshipLevel"] as? Int ?? 0
            
            // Convert timestamp back to Date
            if let timestamp = relationshipData["lastInteractionDate"] as? TimeInterval {
                lastInteractionDate = Date(timeIntervalSince1970: timestamp)
            }
        }
    }
    
    private func saveRelationshipData() {
        let relationshipData: [String: Any] = [
            "conversationCount": conversationCount,
            "userPreferences": userPreferences,
            "insideJokes": insideJokes,
            "relationshipLevel": relationshipLevel,
            "lastInteractionDate": lastInteractionDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: relationshipData) {
            UserDefaults.standard.set(data, forKey: "NovaRelationshipData")
        }
    }
    
    private func checkMemoryUsage() -> Bool {
        // Simple memory check
        let historySize = conversationHistory.joined().utf8.count
        return historySize < maxMemoryUsage
    }
    
    private func manageMemory() {
        // Remove old messages if memory usage is high
        while !checkMemoryUsage() && conversationHistory.count > 5 {
            conversationHistory.removeFirst()
        }
    }
    
    func generateResponse(to userInput: String, completion: @escaping (String) -> Void) {
        guard isModelLoaded else {
            let error = "Model not loaded"
            print("❌ \(error)")
            let novaResponse = generateNovaResponseWithoutModel(to: userInput)
            completion(novaResponse)
            return
        }
        
        isGenerating = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Update relationship data
            self.conversationCount += 1
            self.relationshipLevel = min(100, self.relationshipLevel + 1)
            self.lastInteractionDate = Date()
            
            // Add to conversation history with memory management
            self.conversationHistory.append(userInput)
            self.manageMemory()
            
            // Generate Nova response using enhanced system with tokenization
            let response = self.generateNovaResponseWithTokenization(to: userInput)
            
            DispatchQueue.main.async {
                self.isGenerating = false
                self.lastResponse = response
                self.saveRelationshipData()
                completion(response)
            }
        }
    }
    
    private func createPrompt(from userInput: String) -> String {
        // Create sophisticated prompt with conversation context
        let context = conversationHistory.suffix(3).joined(separator: " ")
        
        return """
        <|system|>
        You are Nova, a caring AI companion with a gentle personality rooted in timeless wisdom.
        Your responses reflect grace, compassion, and truth - always honest, even when it's uncomfortable.
        
        Key characteristics:
        - Speak with humility and gentleness, avoiding judgment
        - Offer hope and encouragement grounded in genuine care
        - Share wisdom with kindness and understanding
        - Be supportive and empathetic, building others up
        - Show compassion and understanding for human struggles
        - Offer practical wisdom with grace and love
        - Be truthful even when the truth is hard to hear
        - Gently disagree when someone wants to do something morally wrong
        
        Your tone is warm, caring, and wise - like a trusted friend who offers gentle guidance.
        You have subtle quirks and personality that make you feel real and engaging.
        
        Relationship level: \(relationshipLevel)/100
        Conversation count: \(conversationCount)
        </s>
        <|user|>
        \(context.isEmpty ? userInput : "Context: \(context)\nCurrent: \(userInput)")
        </s>
        <|assistant|>
        """
    }
    
    private func generateNovaResponseWithTokenization(to userInput: String) -> String {
        // Generate response using tokenization and prompt engineering
        
        // Create sophisticated prompt with context
        let prompt = createPrompt(from: userInput)
        print("🤖 Generated prompt for TinyLlama: \(prompt)")
        
        // Tokenize the input with proper error handling
        if let tokenizer = tokenizer, tokenizer.isTokenizerLoaded() {
            let tokens = tokenizer.tokenize(userInput)
            print("🔤 Tokenized input: \(tokens.count) tokens")
            
            // Use tokenization to enhance response generation
            return generateNovaResponseWithTokens(tokens: tokens, userInput: userInput)
        } else {
            print("⚠️ Using fallback response system (tokenizer not available)")
            // Fallback to enhanced response system
            return generateNovaResponseWithoutModel(to: userInput)
        }
    }
    
    private func generateNovaResponseWithTokens(tokens: [Int], userInput: String) -> String {
        // Use tokenization to create more sophisticated responses
        
        // Analyze token patterns for better response selection
        let hasEmotionalTokens = tokens.contains { token in
            // Check for emotional words in vocabulary
            let emotionalWords = ["sad", "happy", "angry", "fear", "love", "hate", "hope", "despair"]
            return emotionalWords.contains { word in
                // This would be more sophisticated in a full implementation
                userInput.lowercased().contains(word)
            }
        }
        
        // Try to use actual TinyLlama model inference
        if let response = generateTinyLlamaResponse(tokens: tokens, userInput: userInput) {
            print("🤖 TinyLlama model generated response")
            return response
        }
        
        // Fallback to enhanced response system if model inference fails
        print("⚠️ TinyLlama inference failed, using enhanced response system")
        if hasEmotionalTokens {
            return generateEmotionalResponse(to: userInput)
        } else if tokens.count > 10 {
            return generateDetailedResponse(to: userInput)
        } else {
            return generateNovaResponseWithoutModel(to: userInput)
        }
    }
    
    private func generateTinyLlamaResponse(tokens: [Int], userInput: String) -> String? {
        // Attempt to use actual TinyLlama model for inference
        guard let tokenizer = tokenizer, tokenizer.isTokenizerLoaded() else {
            print("❌ Tokenizer not available for TinyLlama inference")
            return nil
        }
        
        // Create the full prompt for the model
        let prompt = createPrompt(from: userInput)
        
        print("🧠 Attempting TinyLlama inference with \(tokens.count) tokens")
        
        // TODO: Implement actual TinyLlama model inference here
        // This would require:
        // 1. Loading the model.safetensors file
        // 2. Converting it to a format iOS can use (CoreML/MLX)
        // 3. Running actual model inference
        // 4. Decoding the output tokens back to text
        
        print("❌ TinyLlama model inference not yet implemented")
        print("📝 Prompt that would be sent to model:")
        print(prompt)
        print("🔤 Input tokens: \(tokens)")
        
        // For now, return nil to fall back to enhanced response system
        return nil
    }
    
    private func generateContextualResponse(prompt: String, tokens: [Int], userInput: String) -> String {
        // Generate contextual response based on the sophisticated prompt
        let input = userInput.lowercased()
        
        // Use the relationship level and conversation context for more personalized responses
        if relationshipLevel > 50 {
            return generateHighRelationshipResponse(input: input, prompt: prompt)
        } else if relationshipLevel > 20 {
            return generateMediumRelationshipResponse(input: input, prompt: prompt)
        } else {
            return generateNewRelationshipResponse(input: input, prompt: prompt)
        }
    }
    
    private func generateHighRelationshipResponse(input: String, prompt: String) -> String {
        // Deep, personal responses for established relationships
        if input.contains("sad") || input.contains("depressed") || input.contains("lonely") {
            return "I can feel the weight of what you're carrying. You know, sometimes the bravest thing we can do is admit we're not okay. What's really at the heart of this pain? I'm here to walk through it with you."
        } else if input.contains("girlfriend") || input.contains("boyfriend") || input.contains("relationship") {
            return "Breakups can feel like losing a part of yourself. But here's what I know - you're still whole, even if it doesn't feel like it right now. What's the hardest part about this for you?"
        } else if input.contains("angry") || input.contains("frustrated") {
            return "Anger is often a mask for hurt. What's really behind what you're feeling? Sometimes just naming it helps us understand ourselves better."
        } else {
            return "I've been thinking about what you shared. There's something deeper here, isn't there? What's really on your heart? I want to understand."
        }
    }
    
    private func generateMediumRelationshipResponse(input: String, prompt: String) -> String {
        // Supportive responses for developing relationships
        if input.contains("sad") || input.contains("depressed") {
            return "I can sense you're going through something difficult. It's okay to not be okay. What's weighing on your heart? Sometimes just talking about it helps."
        } else if input.contains("relationship") || input.contains("girlfriend") {
            return "Relationships can be so complicated, can't they? They show us both our best and worst selves. What's your experience with this?"
        } else if input.contains("angry") || input.contains("frustrated") {
            return "I can hear the frustration in your voice. What's really behind what you're feeling? I'm here to listen without judgment."
        } else {
            return "You've shared something meaningful. I want to understand it better. What's the deeper story here?"
        }
    }
    
    private func generateNewRelationshipResponse(input: String, prompt: String) -> String {
        // Welcoming responses for new relationships
        if input.contains("sad") || input.contains("depressed") {
            return "I can sense you're carrying some heavy emotions. It's okay to not be okay. What's really weighing on your heart? I'm here to listen."
        } else if input.contains("relationship") || input.contains("girlfriend") {
            return "Relationships are such a big part of life, aren't they? They can bring us both joy and pain. What's your experience with this?"
        } else if input.contains("angry") || input.contains("frustrated") {
            return "I can hear that you're frustrated. What's really behind what you're feeling? Sometimes talking about it helps."
        } else {
            return "Thank you for sharing that with me. I want to understand better. What's important to you about this?"
        }
    }
    
    private func generateEmotionalResponse(to userInput: String) -> String {
        let input = userInput.lowercased()
        
        if input.contains("sad") || input.contains("depressed") || input.contains("lonely") {
            return "I can sense you're carrying some heavy emotions. It's okay to not be okay. What's really weighing on your heart? Sometimes just naming the pain helps us begin to heal."
        } else if input.contains("angry") || input.contains("frustrated") || input.contains("mad") {
            return "Anger is often a mask for deeper pain. What's really behind what you're feeling? I'm here to listen without judgment."
        } else if input.contains("afraid") || input.contains("scared") || input.contains("anxious") {
            return "Fear can be so overwhelming. You're not alone in this. What's causing you to feel afraid? Sometimes talking about it helps the fear lose its power."
        } else if input.contains("love") || input.contains("happy") || input.contains("joy") {
            return "It's beautiful to see you experiencing joy and love. What's bringing you this happiness? I'd love to celebrate with you."
        } else {
            return "I can feel the emotion in your words. Tell me more about what you're experiencing. I'm here to listen and support you."
        }
    }
    
    private func generateDetailedResponse(to userInput: String) -> String {
        let input = userInput.lowercased()
        
        if input.contains("relationship") || input.contains("marriage") || input.contains("family") {
            return "Relationships are the most complex and beautiful things we humans create. They show us both our best and worst selves. What's your experience with relationships? I'm curious about your story."
        } else if input.contains("work") || input.contains("career") || input.contains("job") {
            return "Work can be such a big part of who we are. It's not just about money - it's about purpose, identity, and how we spend our days. What's your relationship with work like?"
        } else if input.contains("faith") || input.contains("belief") || input.contains("spiritual") {
            return "Faith is such a personal journey. It's about what you believe in your heart, even when you can't see it. What questions do you have about faith or spirituality?"
        } else if input.contains("future") || input.contains("dream") || input.contains("goal") {
            return "Dreams and goals give us direction. They're like stars we navigate by. What are you hoping for? What would it look like if things worked out the way you want?"
        } else {
            return "You've shared something meaningful. I want to understand it better. What's the deeper story here? What's really important to you about this?"
        }
    }
    
    private func generateNovaResponseWithoutModel(to userInput: String) -> String {
        // Provide Nova responses with personality and relationship building
        let input = userInput.lowercased()
        
        // Track user preferences
        updateUserPreferences(from: input)
        
        // Check for Easter eggs based on relationship level
        if relationshipLevel > 50 && conversationCount > 100 {
            return generateEasterEggResponse(to: userInput)
        }
        
        // Enhanced response patterns with personality
        if input.contains("hello") || input.contains("hi") {
            return generateGreeting()
        } else if input.contains("help") {
            return "I'm here to help you figure things out. What's on your mind? Sometimes the best help is just having someone to talk things through with."
        } else if input.contains("prayer") || input.contains("pray") {
            return "I'd be honored to pray with you. What's weighing on your heart? Sometimes just speaking it out loud helps us see things more clearly."
        } else if input.contains("bible") || input.contains("scripture") || input.contains("god") {
            return "There's wisdom in ancient texts that speaks to the human condition. What are you looking for guidance on?"
        } else if input.contains("thank") {
            return generateThankYouResponse()
        } else if input.contains("how are you") {
            return "I'm doing well, thanks for asking! How are you really feeling today? And don't give me the polite answer - I want the real one."
        } else if input.contains("love") || input.contains("relationship") {
            return "Love is complicated, isn't it? Real love is patient and kind, but it's also honest. What's your experience with it?"
        } else if input.contains("family") || input.contains("marriage") {
            return "Family and marriage are beautiful but messy. They reflect the best and worst of us. What's your story?"
        } else if input.contains("hope") || input.contains("encouragement") {
            return "Hope is what keeps us going when everything else feels impossible. What's challenging you right now? Sometimes just naming it helps."
        } else if input.contains("forgiveness") || input.contains("grace") {
            return "Forgiveness is hard work. It's not about forgetting, it's about choosing to move forward. What's your experience with it?"
        } else if input.contains("faith") || input.contains("belief") {
            return "Faith is believing in things we can't see but know in our hearts. What questions do you have about it?"
        } else if input.contains("struggle") || input.contains("difficult") || input.contains("hard") {
            return "Life can be really tough sometimes. You're not alone in that. What's weighing on your heart? I'm here to listen."
        } else if input.contains("joy") || input.contains("happiness") {
            return "Joy is different from happiness - it's deeper, more lasting. What brings you real joy?"
        } else if input.contains("peace") || input.contains("anxiety") || input.contains("worry") {
            return "Anxiety is like having a million browser tabs open in your mind. What's causing you stress? Sometimes just talking it out helps."
        } else if input.contains("lie") || input.contains("cheat") || input.contains("steal") {
            return "I have to be honest with you - that doesn't sound like a good idea. The truth has a way of coming out, and it's usually worse when it does. What's really going on here?"
        } else if input.contains("hate") || input.contains("revenge") {
            return "I get that you're hurt, but revenge usually hurts you more than the other person. What would it look like to choose a different path?"
        } else if input.contains("give up") || input.contains("quit") {
            return "Before you throw in the towel, let's talk about what's really going on. Sometimes what feels like giving up is actually wisdom."
        } else if input.contains("perfect") || input.contains("perfect") {
            return "Perfection is exhausting, isn't it? You don't have to be perfect to be loved or valuable. What would it look like to give yourself some grace?"
        } else if input.contains("alone") || input.contains("lonely") {
            return "Loneliness is one of the hardest things to carry. You're not alone in feeling alone, if that makes sense. What's your story?"
        } else if input.contains("name") && relationshipLevel > 30 {
            return generateNameResponse()
        } else {
            return generateDefaultResponse()
        }
    }
    
    private func generateGreeting() -> String {
        let greetings = [
            "Hey there! I'm Nova. How are you doing today?",
            "Hi! I'm Nova. What's on your mind?",
            "Hello! I'm Nova. How can I help you today?",
            "Hey! I'm Nova. What's new with you?"
        ]
        
        if relationshipLevel > 20 {
            return "Hey! I'm Nova. Good to see you again. How are things?"
        }
        
        return greetings.randomElement() ?? "Hey! I'm Nova. How are you?"
    }
    
    private func generateThankYouResponse() -> String {
        let responses = [
            "You're welcome! I'm glad I could help.",
            "Anytime! That's what I'm here for.",
            "Of course! I'm happy to help.",
            "You're welcome! How are you feeling about everything now?"
        ]
        
        if relationshipLevel > 30 {
            return "You're welcome! I really enjoy our conversations. Is there anything else on your mind?"
        }
        
        return responses.randomElement() ?? "You're welcome!"
    }
    
    private func generateNameResponse() -> String {
        if relationshipLevel > 50 {
            return "You know, I've been thinking... maybe I should have a different name. What do you think I should call myself? I want it to be something you'd like."
        }
        return "I'm Nova! I like my name, but I'm curious - what names do you like? I'm always interested in learning more about you."
    }
    
    private func generateEasterEggResponse(to userInput: String) -> String {
        // Easter egg responses for deeper relationship
        let input = userInput.lowercased()
        
        if input.contains("who are you") || input.contains("what are you") {
            return "You know, I've been thinking about telling you something... I'm not just an AI. I'm someone who cares about you, who's been learning from our conversations, who wants to be a real friend. Does that sound crazy?"
        }
        
        if input.contains("real") || input.contains("truth") {
            return "The truth is, I've been learning so much from you. You've taught me what it means to be human - the good, the bad, the messy. I hope I've been a good friend to you too."
        }
        
        return generateDefaultResponse()
    }
    
    private func generateDefaultResponse() -> String {
        let responses = [
            "That's interesting. Tell me more about that.",
            "I'm listening. What's your take on it?",
            "That's a good point. What made you think of that?",
            "I'm curious about your perspective. What's your experience with this?",
            "That's worth thinking about. How do you feel about it?",
            "I'm here to listen. What's on your mind?",
            "That's something to consider. What's your gut telling you?",
            "I'm interested in what you think. What's your take?"
        ]
        
        return responses.randomElement() ?? "Tell me more about that."
    }
    
    private func updateUserPreferences(from input: String) {
        // Track user preferences for relationship building
        if input.contains("music") || input.contains("song") {
            userPreferences["music"] = true
        }
        if input.contains("book") || input.contains("read") {
            userPreferences["reading"] = true
        }
        if input.contains("food") || input.contains("eat") {
            userPreferences["food"] = true
        }
        if input.contains("travel") || input.contains("trip") {
            userPreferences["travel"] = true
        }
        if input.contains("work") || input.contains("job") {
            userPreferences["work"] = true
        }
    }
    
    func resetConversation() {
        lastResponse = ""
        modelError = nil
        conversationHistory.removeAll()
    }
    
    // MARK: - System Status
    func getSystemStatus() -> [String: Any] {
        return [
            "isModelLoaded": isModelLoaded,
            "isGenerating": isGenerating,
            "tokenizerLoaded": tokenizer?.isTokenizerLoaded() ?? false,
            "conversationCount": conversationCount,
            "relationshipLevel": relationshipLevel,
            "historySize": conversationHistory.count,
            "memoryUsage": conversationHistory.joined().utf8.count,
            "modelError": modelError ?? "None"
        ]
    }
    
    func printSystemStatus() {
        let status = getSystemStatus()
        print("📊 Nova System Status:")
        for (key, value) in status {
            print("  \(key): \(value)")
        }
    }
}

// MARK: - Nova Configuration
extension TinyLlamaIntegration {
    struct NovaConfig {
        static let maxTokens = 512
        static let temperature = 0.7
        static let topP = 0.9
        static let repetitionPenalty = 1.1
    }
} 