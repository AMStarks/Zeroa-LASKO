import SwiftUI
import Combine

// MARK: - Conversation Models

/// Represents a message in the companion conversation
struct CompanionMessage: Identifiable, Codable {
    let id: String
    let content: String
    let timestamp: Date
    let sender: MessageSender
    let messageType: MessageType
    let context: [String: String]?
    let emotionalContext: ConversationMemory.EmotionalContext?
    
    enum MessageSender: String, Codable {
        case user = "user"
        case companion = "companion"
        case system = "system"
    }
    
    enum MessageType: String, Codable {
        case text = "text"
        case action = "action"
        case suggestion = "suggestion"
        case error = "error"
        case system = "system"
    }
    
    // Custom initializer to handle [String: Any] conversion
    init(id: String, content: String, timestamp: Date, sender: MessageSender, messageType: MessageType, context: [String: Any]?, emotionalContext: ConversationMemory.EmotionalContext?) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.sender = sender
        self.messageType = messageType
        self.emotionalContext = emotionalContext
        
        // Convert [String: Any] to [String: String] for Codable conformance
        if let context = context {
            self.context = context.mapValues { String(describing: $0) }
        } else {
            self.context = nil
        }
    }
}

/// Represents a suggested action or response
struct CompanionSuggestion: Identifiable {
    let id: String
    let text: String
    let action: String?
    let icon: String
}

// MARK: - Conversation View

/// Main conversation interface for AI companion
struct CompanionConversationView: View {
    @StateObject private var companionService = ZeroaAICompanion.shared
    @State private var messages: [CompanionMessage] = []
    @State private var messageText = ""
    @State private var isTyping = false
    @State private var suggestions: [CompanionSuggestion] = []
    @State private var showPersonalityInfo = false
    @State private var showMemoryView = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Messages List
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: DesignSystem.Spacing.md) {
                                // Welcome message if no messages
                                if messages.isEmpty {
                                    WelcomeMessageView()
                                }
                                
                                // Messages
                                ForEach(messages) { message in
                                    CompanionMessageBubble(message: message)
                                        .id(message.id)
                                }
                                
                                // Typing indicator
                                if isTyping {
                                    TypingIndicatorView()
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .padding(.vertical, DesignSystem.Spacing.md)
                        }
                        .onChange(of: messages.count) { _ in
                            if let lastMessage = messages.last {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Suggestions
                    if !suggestions.isEmpty {
                        SuggestionsView(suggestions: suggestions) { suggestion in
                            handleSuggestion(suggestion)
                        }
                    }
                    
                    // Input Area
                    MessageInputView(
                        text: $messageText,
                        isTyping: $isTyping,
                        onSend: sendMessage,
                        isTextFieldFocused: _isTextFieldFocused
                    )
                }
            }
            .navigationTitle(companionService.currentPersonality?.name ?? "AI Companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showPersonalityInfo = true
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(DesignSystem.Colors.text)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showMemoryView = true
                    }) {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(DesignSystem.Colors.text)
                    }
                }
            }
        }
        .sheet(isPresented: $showPersonalityInfo) {
            PersonalityInfoView()
        }
        .sheet(isPresented: $showMemoryView) {
            MemoryView()
        }
        .onAppear {
            loadConversationHistory()
            generateWelcomeMessage()
        }
    }
    
    // MARK: - Message Handling
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = CompanionMessage(
            id: UUID().uuidString,
            content: messageText,
            timestamp: Date(),
            sender: .user,
            messageType: .text,
            context: nil,
            emotionalContext: nil
        )
        
        messages.append(userMessage)
        let userInput = messageText
        messageText = ""
        
        // Generate companion response
        generateCompanionResponse(to: userInput)
    }
    
    private func generateCompanionResponse(to userInput: String) {
        isTyping = true
        
        // Generate response using companion service
        let response = companionService.generateResponse(to: userInput, context: buildContext())
        
        // Add to conversation memory
        companionService.addConversationMemory(
            userInput: userInput,
            companionResponse: response,
            context: buildContext(),
            emotionalContext: .neutral
        )
        
        // Simulate typing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let companionMessage = CompanionMessage(
                id: UUID().uuidString,
                content: response,
                timestamp: Date(),
                sender: .companion,
                messageType: .text,
                context: nil,
                emotionalContext: .neutral
            )
            
            messages.append(companionMessage)
            isTyping = false
            
            // Generate suggestions based on response
            generateSuggestions(for: response)
        }
    }
    
    private func handleSuggestion(_ suggestion: CompanionSuggestion) {
        messageText = suggestion.text
        sendMessage()
    }
    
    private func generateSuggestions(for response: String) {
        // Generate contextual suggestions based on companion response
        let newSuggestions = [
            CompanionSuggestion(id: UUID().uuidString, text: "Tell me more", action: nil, icon: "arrow.right"),
            CompanionSuggestion(id: UUID().uuidString, text: "That's interesting", action: nil, icon: "lightbulb"),
            CompanionSuggestion(id: UUID().uuidString, text: "I have a question", action: nil, icon: "questionmark.circle")
        ]
        
        suggestions = newSuggestions
    }
    
    private func buildContext() -> [String: Any] {
        var context: [String: Any] = [:]
        
        // Add current time
        context["timestamp"] = Date()
        
        // Add recent conversation context
        let recentMessages = messages.suffix(5)
        context["recent_messages"] = recentMessages.map { $0.content }
        
        // Add user preferences if available
        if let preferences = companionService.userPreferences {
            context["user_preferences"] = preferences.preferredTopics
        }
        
        return context
    }
    
    private func loadConversationHistory() {
        // Load recent conversation history
        let recentMemories = companionService.conversationHistory.suffix(10)
        
        for memory in recentMemories {
            let userMessage = CompanionMessage(
                id: UUID().uuidString,
                content: memory.userInput,
                timestamp: memory.timestamp,
                sender: .user,
                messageType: .text,
                context: nil,
                emotionalContext: memory.emotionalContext
            )
            
            let companionMessage = CompanionMessage(
                id: UUID().uuidString,
                content: memory.companionResponse,
                timestamp: memory.timestamp,
                sender: .companion,
                messageType: .text,
                context: nil,
                emotionalContext: memory.emotionalContext
            )
            
            messages.append(userMessage)
            messages.append(companionMessage)
        }
    }
    
    private func generateWelcomeMessage() {
        guard messages.isEmpty else { return }
        
        let welcomeMessage = CompanionMessage(
            id: UUID().uuidString,
            content: "Hello! I'm here to help you. How can I assist you today?",
            timestamp: Date(),
            sender: .companion,
            messageType: .text,
            context: nil,
            emotionalContext: .happy
        )
        
        messages.append(welcomeMessage)
    }
}

// MARK: - Message Components

/// Welcome message shown when conversation is empty
struct WelcomeMessageView: View {
    @StateObject private var companionService = ZeroaAICompanion.shared
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Companion Avatar
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.secondary)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Hello! I'm \(companionService.currentPersonality?.name ?? "your AI companion")")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.text)
                    .multilineTextAlignment(.center)
                
                Text(companionService.currentPersonality?.description ?? "I'm here to help you with various tasks and conversations.")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Quick Start Suggestions
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("You can ask me about:")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignSystem.Spacing.sm) {
                    ForEach(companionService.currentPersonality?.expertiseAreas.prefix(4) ?? [], id: \.self) { area in
                        Text(area.rawValue.capitalized)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(DesignSystem.Colors.surface)
                            .cornerRadius(DesignSystem.CornerRadius.small)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.xl)
    }
}

/// Individual message bubble
struct CompanionMessageBubble: View {
    let message: CompanionMessage
    
    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer()
                
                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                    Text(message.content)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.secondary)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                    
                    Text(formatTimestamp(message.timestamp))
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        // Companion Avatar
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.secondary)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text(message.content)
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.text)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                                .background(DesignSystem.Colors.surface)
                                .cornerRadius(DesignSystem.CornerRadius.medium)
                            
                            Text(formatTimestamp(message.timestamp))
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Typing indicator
struct TypingIndicatorView: View {
    @State private var animationOffset = 0.0
    
    var body: some View {
        HStack {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                // Companion Avatar
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.secondary)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                
                // Typing dots
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(DesignSystem.Colors.textSecondary)
                            .frame(width: 6, height: 6)
                            .scaleEffect(animationOffset == Double(index) ? 1.2 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: animationOffset
                            )
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.surface)
                .cornerRadius(DesignSystem.CornerRadius.medium)
            }
            
            Spacer()
        }
        .onAppear {
            animationOffset = 1.0
        }
    }
}

/// Message input view
struct MessageInputView: View {
    @Binding var text: String
    @Binding var isTyping: Bool
    let onSend: () -> Void
    @FocusState var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(DesignSystem.Colors.surface)
            
            HStack(spacing: DesignSystem.Spacing.md) {
                TextField("Type a message...", text: $text, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .lineLimit(1...4)
                    .onSubmit {
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSend()
                        }
                    }
                
                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.secondary)
                        .clipShape(Circle())
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTyping)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background)
    }
}

/// Suggestions view
struct SuggestionsView: View {
    let suggestions: [CompanionSuggestion]
    let onSuggestionTapped: (CompanionSuggestion) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(DesignSystem.Colors.surface)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(suggestions) { suggestion in
                        Button(action: {
                            onSuggestionTapped(suggestion)
                        }) {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: suggestion.icon)
                                    .font(.system(size: 14))
                                Text(suggestion.text)
                                    .font(DesignSystem.Typography.bodySmall)
                            }
                            .foregroundColor(DesignSystem.Colors.text)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.surface)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
            }
        }
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Supporting Views

/// Personality information view
struct PersonalityInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var companionService = ZeroaAICompanion.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        if let personality = companionService.currentPersonality {
                            // Companion Avatar
                            ZStack {
                                Circle()
                                    .fill(DesignSystem.Colors.secondary)
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: DesignSystem.Spacing.md) {
                                Text(personality.name)
                                    .font(DesignSystem.Typography.titleLarge)
                                    .foregroundColor(DesignSystem.Colors.text)
                                
                                Text(personality.description)
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            // Personality Details
                            CardView {
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    Text("Personality Traits")
                                        .font(DesignSystem.Typography.titleSmall)
                                        .foregroundColor(DesignSystem.Colors.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    VStack(spacing: DesignSystem.Spacing.sm) {
                                        DetailRow(title: "Communication Style", value: personality.communicationStyle.rawValue.capitalized)
                                        DetailRow(title: "Expertise Areas", value: personality.expertiseAreas.map { $0.rawValue.capitalized }.joined(separator: ", "))
                                        DetailRow(title: "Emotional Tone", value: personality.emotionalTone.rawValue.capitalized)
                                        DetailRow(title: "Response Length", value: personality.responseLength.rawValue.capitalized)
                                        DetailRow(title: "Interaction Frequency", value: personality.interactionFrequency.rawValue.capitalized)
                                        DetailRow(title: "Privacy Level", value: personality.privacyLevel.rawValue.capitalized)
                                    }
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        } else {
                            Text("No companion configured")
                                .font(DesignSystem.Typography.titleMedium)
                                .foregroundColor(DesignSystem.Colors.text)
                        }
                    }
                    .padding(.top, DesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Personality Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Memory view showing conversation history
struct MemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var companionService = ZeroaAICompanion.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Text("Conversation Memory")
                            .font(DesignSystem.Typography.titleLarge)
                            .foregroundColor(DesignSystem.Colors.text)
                            .padding(.top, DesignSystem.Spacing.xl)
                        
                        if companionService.conversationHistory.isEmpty {
                            VStack(spacing: DesignSystem.Spacing.md) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 48))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                Text("No conversation history yet")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        } else {
                            LazyVStack(spacing: DesignSystem.Spacing.md) {
                                ForEach(companionService.conversationHistory.suffix(20), id: \.id) { memory in
                                    MemoryCard(memory: memory)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Memory card showing conversation memory entry
struct MemoryCard: View {
    let memory: ConversationMemory
    
    var body: some View {
        CardView {
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    Text(formatTimestamp(memory.timestamp))
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    if let feedback = memory.userFeedback {
                        Image(systemName: feedback == .positive ? "hand.thumbsup.fill" : (feedback == .negative ? "hand.thumbsdown.fill" : "minus"))
                            .foregroundColor(feedback == .positive ? .green : (feedback == .negative ? .red : DesignSystem.Colors.textSecondary))
                    }
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("You: \(memory.userInput)")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Text("Companion: \(memory.companionResponse)")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                if let action = memory.actionTaken {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.secondary)
                        Text("Action: \(action)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
} 