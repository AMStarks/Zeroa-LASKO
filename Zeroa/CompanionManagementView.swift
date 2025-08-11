import SwiftUI

struct CompanionManagementView: View {
    @Binding var path: NavigationPath
    @State private var selectedCompanion: String = "Nova"
    @State private var showingAddCompanion = false
    
    var body: some View {
        NavigationView {
            List {
                Section("AI Companions") {
                    ForEach(["Nova", "TinyLlama", "Enhanced Nova"], id: \.self) { companion in
                        HStack {
                            Text(companion)
                            Spacer()
                            if selectedCompanion == companion {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCompanion = companion
                        }
                    }
                }
                
                Section("Settings") {
                    NavigationLink("Personality Settings") {
                        CompanionSettingsView()
                    }
                    NavigationLink("Conversation History") {
                        CompanionConversationView()
                    }
                }
            }
            .navigationTitle("Companion Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        showingAddCompanion = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddCompanion) {
            AddCompanionView()
        }
    }
}

struct AddCompanionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var companionName = ""
    @State private var companionType = "AI"
    
    var body: some View {
        NavigationView {
            Form {
                Section("Companion Details") {
                    TextField("Name", text: $companionName)
                    Picker("Type", selection: $companionType) {
                        Text("AI").tag("AI")
                        Text("Human").tag("Human")
                    }
                }
            }
            .navigationTitle("Add Companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        // Add companion logic here
                        dismiss()
                    }
                    .disabled(companionName.isEmpty)
                }
            }
        }
    }
} 