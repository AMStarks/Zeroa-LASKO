import SwiftUI

struct CompanionConversationView: View {
    @State private var conversations: [Conversation] = []
    @State private var selectedConversation: Conversation?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(conversations) { conversation in
                    CompanionConversationRow(conversation: conversation)
                        .onTapGesture {
                            selectedConversation = conversation
                        }
                }
            }
            .navigationTitle("Conversation History")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadConversations()
            }
        }
        .sheet(item: $selectedConversation) { conversation in
            ConversationDetailView(conversation: conversation)
        }
    }
    
    private func loadConversations() {
        // Load conversations from storage
        conversations = [
            Conversation(id: "1", name: "Nova", lastMessage: "How are you feeling today?", timestamp: Date()),
            Conversation(id: "2", name: "TinyLlama", lastMessage: "I'm here to help!", timestamp: Date().addingTimeInterval(-3600)),
            Conversation(id: "3", name: "Enhanced Nova", lastMessage: "Let's explore that together.", timestamp: Date().addingTimeInterval(-7200))
        ]
    }
}

struct CompanionConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(conversation.name)
                    .font(.headline)
                Spacer()
                Text(conversation.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(conversation.lastMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

struct ConversationDetailView: View {
    let conversation: Conversation
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Conversation with \(conversation.name)")
                    .font(.title2)
                    .padding()
                
                Spacer()
                
                Text("Conversation details would be displayed here")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle(conversation.name)
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

struct Conversation: Identifiable {
    let id: String
    let name: String
    let lastMessage: String
    let timestamp: Date
} 