import SwiftUI
import Combine

struct TinyLlamaChatView: View {
    @StateObject private var tinyLlamaIntegration = TinyLlamaONNXIntegration()
    @State private var messageText = ""
    @State private var isTyping = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            // Typing indicator
                            if isTyping {
                                TypingIndicator()
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: messages.count) { _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(messages.last?.id ?? "typing", anchor: .bottom)
                        }
                    }
                    .onChange(of: isTyping) { typing in
                        if typing {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("typing", anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Message input
                MessageInputView(
                    text: $messageText,
                    isTyping: $isTyping,
                    onSend: sendMessage
                )
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("TinyLlama")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        messages.removeAll()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            // TinyLlama integration is ready
        }
    }
    
    @State private var messages: [TinyLlamaChatMessage] = []
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        
        // Add user message
        let userChatMessage = TinyLlamaChatMessage(
            id: UUID().uuidString,
            content: userMessage,
            isUser: true,
            timestamp: Date()
        )
        messages.append(userChatMessage)
        
        // Show typing indicator
        isTyping = true
        
        // Get AI response using the real TinyLlama model
        tinyLlamaIntegration.sendMessage(userMessage) { response in
            DispatchQueue.main.async {
                self.isTyping = false
                let aiMessage = TinyLlamaChatMessage(
                    id: UUID().uuidString,
                    content: response,
                    isUser: false,
                    timestamp: Date()
                )
                self.messages.append(aiMessage)
            }
        }
    }
}

struct MessageBubble: View {
    let message: TinyLlamaChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    // AI Avatar
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(.purple)
                        .frame(width: 32, height: 32)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(Circle())
                    
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
                }
                Spacer()
            }
        }
    }
}

struct TypingIndicator: View {
    @State private var animationOffset = 0.0
    
    var body: some View {
        HStack {
            HStack(alignment: .bottom, spacing: 8) {
                // AI Avatar
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.purple)
                    .frame(width: 32, height: 32)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Circle())
                
                // Typing dots
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 8, height: 8)
                            .scaleEffect(animationOffset == Double(index) ? 1.2 : 1.0)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                value: animationOffset
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            Spacer()
        }
        .onAppear {
            animationOffset = 1.0
        }
    }
}

struct MessageInputView: View {
    @Binding var text: String
    @Binding var isTyping: Bool
    let onSend: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                TextField("Message TinyLlama...", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
}

// Chat Service
class TinyLlamaChatService: ObservableObject {
    @Published var messages: [TinyLlamaChatMessage] = []
    @Published var isConnected = false
    
    private let baseURL = "http://localhost:5001"
    private var cancellables = Set<AnyCancellable>()
    
    func connect() {
        // Add welcome message
        addMessage(content: "Hello! I'm TinyLlama, your AI companion. How can I help you today?", isUser: false)
        
        // Check server health
        checkHealth()
    }
    
    func addMessage(content: String, isUser: Bool) {
        let message = TinyLlamaChatMessage(
            id: UUID().uuidString,
            content: content,
            isUser: isUser,
            timestamp: Date()
        )
        messages.append(message)
    }
    
    func sendMessage(_ text: String, completion: @escaping (String) -> Void) {
        let url = URL(string: "\(baseURL)/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "message": text,
            "history": messages.map { [
                "user": $0.isUser ? $0.content : "",
                "assistant": $0.isUser ? "" : $0.content
            ] }.filter { !$0["user"]!.isEmpty || !$0["assistant"]!.isEmpty }
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion("Sorry, I'm having trouble connecting to my brain right now.")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion("Sorry, I'm having trouble thinking right now. Error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    completion("Sorry, I didn't get a response from my brain.")
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let response = json?["response"] as? String ?? "I'm not sure how to respond to that."
                    completion(response)
                } catch {
                    completion("Sorry, I had trouble understanding my own response.")
                }
            }
        }.resume()
    }
    
    func clearMessages() {
        messages.removeAll()
        addMessage(content: "Hello! I'm TinyLlama, your AI companion. How can I help you today?", isUser: false)
    }
    
    private func checkHealth() {
        guard let url = URL(string: "\(baseURL)/health") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let modelLoaded = json["model_loaded"] as? Bool {
                    self.isConnected = modelLoaded
                } else {
                    self.isConnected = false
                }
            }
        }.resume()
    }
}

struct TinyLlamaChatMessage: Identifiable {
    let id: String
    let content: String
    let isUser: Bool
    let timestamp: Date
} 