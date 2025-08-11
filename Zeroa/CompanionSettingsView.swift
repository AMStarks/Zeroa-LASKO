import SwiftUI

struct CompanionSettingsView: View {
    @State private var selectedCompanion = "Nova"
    @State private var personalityTraits: [String: Bool] = [
        "Compassionate": true,
        "Wise": true,
        "Encouraging": true,
        "Direct": false,
        "Humorous": false,
        "Spiritual": true
    ]
    @State private var responseLength = 2.0
    @State private var enableMemory = true
    @State private var enableLearning = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("Companion Selection") {
                    Picker("Active Companion", selection: $selectedCompanion) {
                        Text("Nova").tag("Nova")
                        Text("TinyLlama").tag("TinyLlama")
                        Text("Enhanced Nova").tag("Enhanced Nova")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Personality Traits") {
                    ForEach(Array(personalityTraits.keys.sorted()), id: \.self) { trait in
                        Toggle(trait, isOn: Binding(
                            get: { personalityTraits[trait] ?? false },
                            set: { personalityTraits[trait] = $0 }
                        ))
                    }
                }
                
                Section("Response Settings") {
                    VStack(alignment: .leading) {
                        Text("Response Length")
                        HStack {
                            Text("Short")
                            Slider(value: $responseLength, in: 1...5, step: 1)
                            Text("Long")
                        }
                        Text("Level: \(Int(responseLength))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("AI Behavior") {
                    Toggle("Enable Memory", isOn: $enableMemory)
                    Toggle("Enable Learning", isOn: $enableLearning)
                }
                
                Section("Advanced") {
                    NavigationLink("Model Configuration") {
                        ModelConfigView()
                    }
                    NavigationLink("Training Data") {
                        TrainingDataView()
                    }
                }
            }
            .navigationTitle("Companion Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                }
            }
        }
    }
    
    private func saveSettings() {
        // Save settings logic here
        print("Settings saved for \(selectedCompanion)")
    }
}

struct ModelConfigView: View {
    var body: some View {
        VStack {
            Text("Model Configuration")
                .font(.title2)
                .padding()
            
            Text("Advanced model settings would be configured here")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .navigationTitle("Model Config")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TrainingDataView: View {
    var body: some View {
        VStack {
            Text("Training Data")
                .font(.title2)
                .padding()
            
            Text("Training data management would be here")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .navigationTitle("Training Data")
        .navigationBarTitleDisplayMode(.inline)
    }
} 