import SwiftUI
import Combine

// MARK: - TLS Blockchain Messaging View
struct TLSMessagingView: View {
    @StateObject private var tlsMessagingService = TLSMessagingService.shared
    @State private var messageText = ""
    @State private var recipientAddress = ""
    @State private var showNewMessage = false
    @State private var selectedConversation: TLSConversation?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSending = false
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("TLS Blockchain Messages")
                            .font(DesignSystem.Typography.titleLarge)
                            .foregroundColor(DesignSystem.Colors.text)
                        
                        Spacer()
                        
                        Button(action: {
                            showNewMessage = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(DesignSystem.Colors.secondary)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.lg)
                    
                    // Connection Status
                    HStack {
                        Circle()
                            .fill(tlsMessagingService.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(tlsMessagingService.isConnected ? "Connected to TLS Blockchain" : "Disconnected")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Spacer()
                        
                        if tlsMessagingService.isConnected {
                            Text("Block \(tlsMessagingService.lastBlockHeight)")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.surface)
                    .cornerRadius(DesignSystem.CornerRadius.small)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    
                    // Conversations List
                    ScrollView {
                        LazyVStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(tlsMessagingService.conversations) { conversation in
                                TLSConversationRow(conversation: conversation)
                                    .onTapGesture {
                                        selectedConversation = conversation
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
            Task {
                await tlsMessagingService.connect()
            }
        }
        .sheet(isPresented: $showNewMessage) {
            NewTLSMessageView(
                recipientAddress: $recipientAddress,
                messageText: $messageText,
                isSending: $isSending,
                showAlert: $showAlert,
                alertMessage: $alertMessage
            )
        }
        .sheet(item: $selectedConversation) { conversation in
            TLSConversationView(conversation: conversation)
        }
        .alert("Message Status", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
}

// MARK: - TLS Conversation Row
struct TLSConversationRow: View {
    let conversation: TLSConversation
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Blockchain Icon
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.secondary)
                    .frame(width: 50, height: 50)
                
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack {
                    Text("TLS Conversation")
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lastMessage.content)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(2)
                        
                        HStack {
                            Text("TX: \(String(lastMessage.txid?.prefix(8) ?? "Pending"))")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            if let blockHeight = lastMessage.blockHeight {
                                Text("Block \(blockHeight)")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            
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
                } else {
                    Text("No messages yet")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .italic()
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

// MARK: - New TLS Message View
struct NewTLSMessageView: View {
    @Binding var recipientAddress: String
    @Binding var messageText: String
    @Binding var isSending: Bool
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tlsMessagingService = TLSMessagingService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(DesignSystem.Colors.secondary)
                        
                        Spacer()
                        
                        Text("New TLS Message")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.text)
                        
                        Spacer()
                        
                        Button("Send") {
                            sendMessage()
                        }
                        .foregroundColor(DesignSystem.Colors.secondary)
                        .disabled(recipientAddress.isEmpty || messageText.isEmpty || isSending)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.lg)
                    
                    // Form
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Recipient TLS Address")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.text)
                            
                            TextField("Enter TLS wallet address", text: $recipientAddress)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(DesignSystem.Typography.bodyMedium)
                        }
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Message")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.text)
                            
                            TextEditor(text: $messageText)
                                .frame(minHeight: 100)
                                .padding(DesignSystem.Spacing.sm)
                                .background(DesignSystem.Colors.surface)
                                .cornerRadius(DesignSystem.CornerRadius.small)
                                .font(DesignSystem.Typography.bodyMedium)
                        }
                        
                        if isSending {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Sending via TLS blockchain...")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    Spacer()
                }
            }
        }
        .alert("Message Status", isPresented: $showAlert) {
            Button("OK") {
                if alertMessage.contains("success") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func sendMessage() {
        guard !recipientAddress.isEmpty && !messageText.isEmpty else { return }
        
        isSending = true
        
        Task {
            let response = await tlsMessagingService.sendMessage(
                to: recipientAddress,
                content: messageText,
                messageType: .text
            )
            
            await MainActor.run {
                isSending = false
                
                if response.success {
                    alertMessage = "Message sent successfully! Transaction ID: \(response.txid?.prefix(8) ?? "Pending")"
                    messageText = ""
                    recipientAddress = ""
                } else {
                    alertMessage = "Failed to send message: \(response.error ?? "Unknown error")"
                }
                
                showAlert = true
            }
        }
    }
}

// MARK: - TLS Conversation View
struct TLSConversationView: View {
    let conversation: TLSConversation
    @State private var messageText = ""
    @State private var isSending = false
    @StateObject private var tlsMessagingService = TLSMessagingService.shared
    @Environment(\.dismiss) private var dismiss
    
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
                            Text("TLS Conversation")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.text)
                            
                            Text("Blockchain Messages")
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
                    ScrollView {
                        LazyVStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(tlsMessagingService.messages.filter { message in
                                let messageConversationId = [message.senderAddress, message.receiverAddress].sorted().joined(separator: "_")
                                return messageConversationId == conversation.id
                            }) { message in
                                TLSMessageBubble(message: message)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                    }
                    
                    // Message Input
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        TextField("Type a message...", text: $messageText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(isSending)
                        
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(DesignSystem.Colors.secondary)
                        }
                        .disabled(messageText.isEmpty || isSending)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.surface)
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        isSending = true
        
        // Get the other participant's address
        let currentAddress = WalletService.shared.loadAddress() ?? ""
        let otherParticipant = conversation.participants.first { $0 != currentAddress } ?? ""
        
        Task {
            let response = await tlsMessagingService.sendMessage(
                to: otherParticipant,
                content: messageText,
                messageType: .text
            )
            
            await MainActor.run {
                isSending = false
                messageText = ""
                
                if !response.success {
                    print("Failed to send message: \(response.error ?? "Unknown error")")
                }
            }
        }
    }
}

// MARK: - TLS Message Bubble
struct TLSMessageBubble: View {
    let message: TLSMessage
    
    var body: some View {
        HStack {
            if message.senderAddress == WalletService.shared.loadAddress() {
                Spacer()
            }
            
            VStack(alignment: message.senderAddress == WalletService.shared.loadAddress() ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(.white)
                    .padding(DesignSystem.Spacing.sm)
                    .background(
                        message.senderAddress == WalletService.shared.loadAddress() 
                            ? DesignSystem.Colors.secondary 
                            : DesignSystem.Colors.surface
                    )
                    .cornerRadius(DesignSystem.CornerRadius.small)
                
                HStack(spacing: 4) {
                    Text(formatDate(message.timestamp))
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    if let txid = message.txid {
                        Text("TX: \(String(txid.prefix(6)))")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    if let blockHeight = message.blockHeight {
                        Text("Block \(blockHeight)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            
            if message.senderAddress != WalletService.shared.loadAddress() {
                Spacer()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
} 