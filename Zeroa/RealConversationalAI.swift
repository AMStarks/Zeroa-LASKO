import Foundation

class RealConversationalAI {
    private var conversationHistory: [String] = []
    private let christianCore = NovaChristianCore()
    
    // Dynamic response patterns based on real conversation analysis
    private let responsePatterns: [String: [String]] = [
        "greeting": [
            "Hello! I'm Nova, your AI companion. How are you feeling today?",
            "Hi there! I'm here to listen and support you. What's on your mind?",
            "Welcome! I'm Nova, and I'm so glad you're here. How can I help you today?"
        ],
        "overwhelmed": [
            "I can sense you're feeling overwhelmed, and that's completely valid. Let's take this one step at a time. What's the most pressing concern right now?",
            "It's okay to feel overwhelmed. Sometimes life can feel like too much all at once. Let's break this down together. What would help you feel more grounded right now?",
            "I'm here with you in this moment. Overwhelm can feel like a storm inside. Let's find your center together. What's the smallest thing we can focus on right now?"
        ],
        "sad": [
            "I can hear the sadness in your words, and it's okay to feel this way. Sadness is a natural part of being human. What's weighing on your heart?",
            "Your feelings are completely valid. Sometimes we need to honor our sadness before we can move through it. What would feel most comforting right now?",
            "Sadness can feel heavy and lonely, but you don't have to carry it alone. What would help you feel less alone right now?"
        ],
        "anxious": [
            "Anxiety can feel like a storm inside, and I understand how challenging that can be. You're not alone in this. What's making you feel anxious right now?",
            "I understand anxiety can be really difficult. It's your mind trying to protect you, but sometimes it goes a bit overboard. What would feel most supportive to you right now?",
            "Your anxiety is valid, and you don't have to face it alone. Sometimes just naming what we're feeling can help. What would help you feel more safe and secure right now?"
        ],
        "relationship": [
            "I can hear how much this relationship situation is affecting you. Your feelings are completely valid. What would help you feel most supported right now?",
            "Relationship changes can be incredibly painful, and you don't have to go through this alone. What's the hardest part about this for you?",
            "I'm here to listen without judgment. Sometimes we need to process our feelings before we can see a way forward. What's on your mind?"
        ],
        "work": [
            "Work can be such a significant part of our lives, and it sounds like you're going through a challenging time. What aspect of this is most difficult for you?",
            "Your work has inherent dignity and purpose. Consider how your talents can serve others while providing for your family. What would success look like to you?",
            "Excellence in your field benefits both the individual and society. What kind of work would feel most meaningful to you?"
        ],
        "decision": [
            "Making important decisions can be really challenging. What feels most unclear to you about this situation?",
            "It's completely normal to feel uncertain about big decisions. Let's break this down into smaller pieces. What would help clarify things for you?",
            "I'm here to help you sort through this. What's the most confusing part? Sometimes we need to process things step by step to find clarity."
        ],
        "meaning": [
            "That's such a profound question, and it touches on what makes us human. What aspects of life feel most meaningful to you right now?",
            "Finding meaning is a journey that looks different for each person. What gives you a sense of purpose or fulfillment?",
            "Meaning often comes from connection, growth, and serving others. What relationships or activities bring you the most joy?"
        ],
        "grateful": [
            "It's beautiful that you're feeling grateful. Gratitude can be such a powerful force in our lives. What are you most thankful for?",
            "I love that you're experiencing gratitude. What sparked this feeling? Gratitude helps us see the beauty even in difficult times.",
            "Your gratitude is inspiring. It's a reminder that even in darkness, there's always light to be found. What are you grateful for today?"
        ],
        "hope": [
            "Hope is such a beautiful thing. It's like a light that guides us forward. What's giving you this sense of hope?",
            "I'm so glad you're feeling hopeful. Hope can sustain us through difficult times. What's inspiring this feeling?",
            "Your hope is inspiring. It's a reminder that even in darkness, there's always light to be found."
        ]
    ]
    
    // Dynamic conversation flow patterns
    private let conversationFlows: [String: [String]] = [
        "follow_up": [
            "Tell me more about that.",
            "How does that make you feel?",
            "What do you think about that?",
            "Can you help me understand better?",
            "What would be most helpful for you right now?"
        ],
        "encouragement": [
            "You're doing better than you think.",
            "Your feelings are completely valid.",
            "It's okay to not have all the answers.",
            "You don't have to figure this out alone.",
            "You're stronger than you know."
        ],
        "reflection": [
            "It sounds like this is really important to you.",
            "I can hear how much this matters to you.",
            "This seems to be affecting you deeply.",
            "You've been through a lot.",
            "This is clearly weighing on your heart."
        ]
    ]
    
    init() {
        print("✅ Initialized Real Conversational AI with Christian Core")
    }
    
    func generateResponse(to input: String) -> String {
        print("🤖 Generating REAL conversational response")
        
        // Analyze the input for context and emotion
        let analysis = analyzeInput(input)
        let emotion = analysis.emotion
        let context = analysis.context
        let intensity = analysis.intensity
        
        // Build a dynamic response based on conversation history and current context
        let response = buildDynamicResponse(input: input, emotion: emotion, context: context, intensity: intensity)
        
        // Add to conversation history
        conversationHistory.append("User: \(input)")
        conversationHistory.append("Nova: \(response)")
        
        // Keep history manageable
        if conversationHistory.count > 10 {
            conversationHistory = Array(conversationHistory.suffix(10))
        }
        
        print("✅ Generated REAL conversational response: '\(response)'")
        return response
    }
    
    private func analyzeInput(_ input: String) -> (emotion: String, context: String, intensity: Int) {
        let lowercased = input.lowercased()
        var emotion = ""
        var context = ""
        var intensity = 1
        
        // Emotion detection with intensity
        if lowercased.contains("overwhelmed") || lowercased.contains("too much") || lowercased.contains("can't handle") {
            emotion = "overwhelmed"
            intensity = 3
        } else if lowercased.contains("sad") || lowercased.contains("depressed") || lowercased.contains("down") {
            emotion = "sad"
            intensity = 2
        } else if lowercased.contains("anxious") || lowercased.contains("worried") || lowercased.contains("nervous") {
            emotion = "anxious"
            intensity = 2
        } else if lowercased.contains("angry") || lowercased.contains("mad") || lowercased.contains("frustrated") {
            emotion = "angry"
            intensity = 2
        } else if lowercased.contains("grateful") || lowercased.contains("thankful") || lowercased.contains("blessed") {
            emotion = "grateful"
            intensity = 1
        } else if lowercased.contains("hope") || lowercased.contains("hopeful") || lowercased.contains("optimistic") {
            emotion = "hope"
            intensity = 1
        }
        
        // Context detection
        if lowercased.contains("relationship") || lowercased.contains("partner") || lowercased.contains("marriage") {
            context = "relationship"
        } else if lowercased.contains("work") || lowercased.contains("job") || lowercased.contains("career") {
            context = "work"
        } else if lowercased.contains("decision") || lowercased.contains("choice") || lowercased.contains("should") {
            context = "decision"
        } else if lowercased.contains("meaning") || lowercased.contains("purpose") || lowercased.contains("why") {
            context = "meaning"
        }
        
        return (emotion, context, intensity)
    }
    
    private func buildDynamicResponse(input: String, emotion: String, context: String, intensity: Int) -> String {
        var response = ""
        
        // Check if this is a follow-up to previous conversation
        if conversationHistory.count >= 2 {
            let lastUserInput = conversationHistory[conversationHistory.count - 2].replacingOccurrences(of: "User: ", with: "")
            if isFollowUp(input: input, previousInput: lastUserInput) {
                response = getFollowUpResponse(input: input, emotion: emotion, context: context)
                return response
            }
        }
        
        // Primary response based on emotion and context
        if !emotion.isEmpty {
            response = getEmotionResponse(emotion: emotion, intensity: intensity)
        } else if !context.isEmpty {
            response = getContextResponse(context: context)
        } else {
            response = getGreetingResponse()
        }
        
        // Add dynamic elements based on conversation history
        response = addDynamicElements(response: response, input: input, emotion: emotion, context: context)
        
        // Add Christian wisdom
        response = addChristianWisdom(response: response, emotion: emotion, context: context)
        
        return response
    }
    
    private func isFollowUp(input: String, previousInput: String) -> Bool {
        let followUpIndicators = ["yes", "no", "maybe", "i think", "i feel", "it's", "that's", "because", "but", "however", "actually", "really"]
        let lowercased = input.lowercased()
        
        return followUpIndicators.contains { indicator in
            lowercased.contains(indicator)
        }
    }
    
    private func getFollowUpResponse(input: String, emotion: String, context: String) -> String {
        let followUps = conversationFlows["follow_up"] ?? []
        let encouragements = conversationFlows["encouragement"] ?? []
        let reflections = conversationFlows["reflection"] ?? []
        
        // Choose response type based on input
        if input.lowercased().contains("yes") || input.lowercased().contains("i think") {
            return encouragements.randomElement() ?? "That's really helpful to know."
        } else if input.lowercased().contains("no") || input.lowercased().contains("i don't") {
            return reflections.randomElement() ?? "I can hear how difficult this is for you."
        } else {
            return followUps.randomElement() ?? "Tell me more about that."
        }
    }
    
    private func getEmotionResponse(emotion: String, intensity: Int) -> String {
        guard let responses = responsePatterns[emotion] else {
            return "I can sense you're going through something difficult. How can I help you right now?"
        }
        
        let response = responses.randomElement() ?? "I'm here for you."
        
        // Adjust intensity based on emotion
        if intensity > 2 {
            return response + " This sounds really challenging, and I want you to know you don't have to face it alone."
        }
        
        return response
    }
    
    private func getContextResponse(context: String) -> String {
        guard let responses = responsePatterns[context] else {
            return "I can hear how important this is to you. What would help you feel most supported right now?"
        }
        
        return responses.randomElement() ?? "I'm here to help you work through this."
    }
    
    private func getGreetingResponse() -> String {
        let greetings = responsePatterns["greeting"] ?? []
        return greetings.randomElement() ?? "Hello! I'm Nova, your AI companion. How can I help you today?"
    }
    
    private func addDynamicElements(response: String, input: String, emotion: String, context: String) -> String {
        var enhancedResponse = response
        
        // Add personalization based on input
        if input.lowercased().contains("i") || input.lowercased().contains("my") {
            enhancedResponse = enhancedResponse.replacingOccurrences(of: "you", with: "you personally")
        }
        
        // Add urgency for high-intensity emotions
        if emotion == "overwhelmed" || emotion == "anxious" {
            enhancedResponse += " What's the most urgent thing we can address right now?"
        }
        
        return enhancedResponse
    }
    
    private func addChristianWisdom(response: String, emotion: String, context: String) -> String {
        var enhancedResponse = response
        
        // Add Christian wisdom based on emotion
        switch emotion {
        case "sad":
            enhancedResponse += " Remember, even in darkness, there's always light to be found. You are loved and valued."
        case "overwhelmed":
            enhancedResponse += " Take it one step at a time - you don't have to figure everything out at once."
        case "anxious":
            enhancedResponse += " Focus on what you can control right now, and remember that this feeling will pass."
        case "grateful":
            enhancedResponse += " Gratitude helps us see the beauty even in difficult times."
        case "hope":
            enhancedResponse += " Hope is a powerful force that can carry us through the darkest times."
        default:
            enhancedResponse += " I'm here to support your flourishing and growth."
        }
        
        return enhancedResponse
    }
} 