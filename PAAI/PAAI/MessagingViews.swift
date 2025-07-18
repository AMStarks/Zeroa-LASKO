import SwiftUI
import Combine

// MARK: - Messaging Views
struct ConversationsListView: View {
    @Binding var conversations: [ChatConversation]
    @Binding var currentConversation: ChatConversation?
    @Binding var showNewChat: Bool
    @StateObject private var messagingService = MessagingService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("messages".localized)
                            .font(DesignSystem.Typography.titleLarge)
                            .foregroundColor(DesignSystem.Colors.text)
                        
                        Spacer()
                        
                        Button(action: {
                            showNewChat = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(DesignSystem.Colors.secondary)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.lg)
                    
                    // Conversations List
                    ScrollView {
                        LazyVStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(conversations) { conversation in
                                ConversationRow(conversation: conversation)
                                    .onTapGesture {
                                        currentConversation = conversation
                                    }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                    }
                }
            }
        }
        .onAppear {
            messagingService.connect()
        }
    }
}

struct ConversationRow: View {
    let conversation: ChatConversation
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Avatar
            Circle()
                .fill(DesignSystem.Colors.secondary)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(conversation.groupName?.prefix(1) ?? "C"))
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack {
                    Text(conversation.groupName ?? "Conversation")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Spacer()
                    
                    if let lastMessage = conversation.lastMessage {
                        Text(formatDate(lastMessage.timestamp))
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                
                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage.content)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                } else {
                    Text("no_messages_yet".localized)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .italic()
                }
                
                HStack {
                    Text("\(conversation.participants.count) \("participants".localized)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(DesignSystem.Colors.secondary)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ChatView: View {
    @Binding var conversation: ChatConversation
    @Binding var messageText: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var messagingService = MessagingService.shared
    @State private var messages: [ChatMessage] = []
    @State private var isTyping = false
    @State private var typingTimer: Timer?
    
    private var otherParticipant: String {
        // Get the other participants address
        let currentAddress = WalletService.shared.loadAddress() ?? ""
        return conversation.participants.first { $0 != currentAddress } ?? ""
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button("Back") {
                            dismiss()
                        }
                        .foregroundColor(DesignSystem.Colors.secondary)
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text(conversation.groupName ?? "Conversation")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.text)
                            
                            Text("\(conversation.participants.count) \("participants".localized)")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            // More options
                        }) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20))
                                .foregroundColor(DesignSystem.Colors.text)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.surface)
                    
                    // Messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(messages) { message in
                                    MessageBubble(message: message, isFromCurrentUser: message.senderAddress == WalletService.shared.loadAddress())
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .padding(.vertical, DesignSystem.Spacing.md)
                        }
                        .onChange(of: messages.count) { oldValue, newValue in
                            if let lastMessage = messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Message Input
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Button(action: {
                            // Attach file
                        }) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 20))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        InputField("type_message".localized, text: $messageText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: messageText) { oldValue, newValue in
                                Task {
                                    await handleTyping()
                                }
                            }
                        
                        Button(action: {
                            sendMessage()
                        }) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(DesignSystem.Colors.primary)
                                .clipShape(Circle())
                        }
                        .disabled(messageText.isEmpty)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.surface)
                }
            }
        }
        .onAppear {
            loadMessages()
        }
    }
    
    private func loadMessages() { // Load messages for this conversation
        messages = messagingService.messages.filter { message in
            let messageConversationId = [message.senderAddress, message.receiverAddress].sorted().joined(separator: "_")
            let conversationId = conversation.participants.sorted().joined(separator: "_")
            return messageConversationId == conversationId
        }
    }
    
    private func handleTyping() async {
        await messagingService.sendTypingIndicator(to: otherParticipant, isTyping: true)
        
        // Reset typing timer
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            Task {
                await messagingService.sendTypingIndicator(to: otherParticipant, isTyping: false)
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        messagingService.sendMessage(
            to: otherParticipant,
            content: messageText,
            messageType: .text
        )
        
        messageText = ""
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: DesignSystem.Spacing.xs) {
                Text(message.content)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(isFromCurrentUser ? .white : DesignSystem.Colors.text)
                    .padding(DesignSystem.Spacing.md)
                    .background(
                        isFromCurrentUser ? DesignSystem.Colors.primary : DesignSystem.Colors.surface
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
                
                Text(formatTime(message.timestamp))
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            if !isFromCurrentUser {
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct NewChatView: View {
    @Binding var newContactName: String
    @Binding var newContactAddress: String
    @Binding var conversations: [ChatConversation]
    @Environment(\.dismiss) private var dismiss
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack {
                    // Header
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(DesignSystem.Colors.secondary)
                        
                        Spacer()
                        
                        Text("new_chat".localized)
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.text)
                        
                        Spacer()
                        
                        Button("create".localized) {
                            createNewChat()
                        }
                        .foregroundColor(DesignSystem.Colors.secondary)
                        .disabled(newContactName.isEmpty || newContactAddress.isEmpty)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.lg)
                    
                    // Form
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            CardView {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                    Text("contact_information".localized)
                                        .font(DesignSystem.Typography.headline)
                                        .foregroundColor(DesignSystem.Colors.text)
                                    
                                    InputField("contact_name".localized, text: $newContactName)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    InputField("tls_address_field".localized, text: $newContactAddress)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        }
                    }
                }
            }
        }
        .alert("new_chat".localized, isPresented: $showAlert) {
            Button("ok".localized) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func createNewChat() {
        // Create a new ChatConversation using the MessagingService model
        let newConversation = ChatConversation(
            id: UUID().uuidString,
            participants: [newContactAddress], // Add current user's address here
            lastMessage: nil,
            unreadCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            isGroupChat: false,
            groupName: newContactName,
            groupAvatar: nil
        )
        
        conversations.append(newConversation)
        
        alertMessage = "new_conversation_created".localized
        showAlert = true
        
        // Clear form
        newContactName = ""
        newContactAddress = ""
        // Dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
}

 