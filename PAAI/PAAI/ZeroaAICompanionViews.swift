import SwiftUI
import Combine

// MARK: - AI Companion Views

/// Main companion management view
struct CompanionManagementView: View {
    @StateObject private var companionService = ZeroaAICompanion.shared
    @StateObject private var marketplace = CompanionMarketplace()
    @State private var showCreateCompanion = false
    @State private var showMarketplace = false
    @State private var showSettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Text("AI Companion")
                            .font(DesignSystem.Typography.titleLarge)
                            .foregroundColor(DesignSystem.Colors.text)
                        
                        Text("Your personalized AI assistant")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.top, DesignSystem.Spacing.xl)
                    
                    // Current Companion Status
                    if let personality = companionService.currentPersonality {
                        CurrentCompanionCard(personality: personality)
                    } else {
                        NoCompanionCard {
                            showCreateCompanion = true
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: DesignSystem.Spacing.md) {
                        if companionService.currentPersonality != nil {
                            Button(action: {
                                // Start conversation
                            }) {
                                HStack {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 18))
                                    Text("Start Conversation")
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.md)
                                .background(DesignSystem.Colors.secondary)
                                .cornerRadius(DesignSystem.CornerRadius.medium)
                            }
                            
                            Button(action: {
                                showSettings = true
                            }) {
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 18))
                                    Text("Companion Settings")
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(DesignSystem.Colors.text)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.md)
                                .background(DesignSystem.Colors.surface)
                                .cornerRadius(DesignSystem.CornerRadius.medium)
                            }
                        }
                        
                        Button(action: {
                            showMarketplace = true
                        }) {
                            HStack {
                                Image(systemName: "store.fill")
                                    .font(.system(size: 18))
                                Text("Companion Marketplace")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(DesignSystem.Colors.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.surface)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showCreateCompanion) {
            CreateCompanionView()
        }
        .sheet(isPresented: $showMarketplace) {
            CompanionMarketplaceView()
        }
        .sheet(isPresented: $showSettings) {
            CompanionSettingsView()
        }
    }
}

/// Card showing current companion information
struct CurrentCompanionCard: View {
    let personality: CompanionPersonality
    
    var body: some View {
        CardView {
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text(personality.name)
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.text)
                        
                        Text(personality.description)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Companion Avatar
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.secondary)
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                
                // Personality Traits
                VStack(spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("Communication Style")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text(personality.communicationStyle.rawValue.capitalized)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.text)
                    }
                    
                    HStack {
                        Text("Expertise")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text(personality.expertiseAreas.map { $0.rawValue.capitalized }.joined(separator: ", "))
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.text)
                            .lineLimit(1)
                    }
                    
                    HStack {
                        Text("Emotional Tone")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text(personality.emotionalTone.rawValue.capitalized)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.text)
                    }
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
}

/// Card shown when no companion is created
struct NoCompanionCard: View {
    let onCreateCompanion: () -> Void
    
    var body: some View {
        CardView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(DesignSystem.Colors.secondary)
                
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("No AI Companion")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Text("Create your personalized AI companion to get started")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                Button(action: onCreateCompanion) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 18))
                        Text("Create Companion")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.secondary)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
}

/// View for creating a new AI companion
struct CreateCompanionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var companionService = ZeroaAICompanion.shared
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedCommunicationStyle = CompanionPersonality.CommunicationStyle.friendly
    @State private var selectedExpertise: Set<CompanionPersonality.ExpertiseArea> = []
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Header
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Text("Create AI Companion")
                                .font(DesignSystem.Typography.titleLarge)
                                .foregroundColor(DesignSystem.Colors.text)
                            
                            Text("Design your personalized AI assistant")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .padding(.top, DesignSystem.Spacing.xl)
                        
                        // Basic Information
                        CardView {
                            VStack(spacing: DesignSystem.Spacing.md) {
                                Text("Basic Information")
                                    .font(DesignSystem.Typography.titleSmall)
                                    .foregroundColor(DesignSystem.Colors.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    TextField("Companion Name", text: $name)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    TextField("Description", text: $description, axis: .vertical)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .lineLimit(3...6)
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        // Communication Style
                        CardView {
                            VStack(spacing: DesignSystem.Spacing.md) {
                                Text("Communication Style")
                                    .font(DesignSystem.Typography.titleSmall)
                                    .foregroundColor(DesignSystem.Colors.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignSystem.Spacing.sm) {
                                    ForEach(CompanionPersonality.CommunicationStyle.allCases, id: \.self) { style in
                                        Button(action: {
                                            selectedCommunicationStyle = style
                                        }) {
                                            VStack(spacing: DesignSystem.Spacing.sm) {
                                                Text(style.rawValue.capitalized)
                                                    .font(DesignSystem.Typography.bodyMedium)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(selectedCommunicationStyle == style ? .white : DesignSystem.Colors.text)
                                                
                                                Text(getCommunicationStyleDescription(style))
                                                    .font(DesignSystem.Typography.caption)
                                                    .foregroundColor(selectedCommunicationStyle == style ? .white.opacity(0.8) : DesignSystem.Colors.textSecondary)
                                                    .multilineTextAlignment(.center)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, DesignSystem.Spacing.md)
                                            .background(selectedCommunicationStyle == style ? DesignSystem.Colors.secondary : DesignSystem.Colors.surface)
                                            .cornerRadius(DesignSystem.CornerRadius.small)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        // Expertise Areas
                        CardView {
                            VStack(spacing: DesignSystem.Spacing.md) {
                                Text("Expertise Areas")
                                    .font(DesignSystem.Typography.titleSmall)
                                    .foregroundColor(DesignSystem.Colors.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignSystem.Spacing.sm) {
                                    ForEach(CompanionPersonality.ExpertiseArea.allCases, id: \.self) { area in
                                        Button(action: {
                                            if selectedExpertise.contains(area) {
                                                selectedExpertise.remove(area)
                                            } else {
                                                selectedExpertise.insert(area)
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: selectedExpertise.contains(area) ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(selectedExpertise.contains(area) ? DesignSystem.Colors.secondary : DesignSystem.Colors.textSecondary)
                                                
                                                Text(area.rawValue.capitalized)
                                                    .font(DesignSystem.Typography.bodyMedium)
                                                    .foregroundColor(DesignSystem.Colors.text)
                                                
                                                Spacer()
                                            }
                                            .padding(.vertical, DesignSystem.Spacing.sm)
                                            .padding(.horizontal, DesignSystem.Spacing.md)
                                            .background(selectedExpertise.contains(area) ? DesignSystem.Colors.secondary.opacity(0.1) : DesignSystem.Colors.surface)
                                            .cornerRadius(DesignSystem.CornerRadius.small)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        // Create Button
                        Button(action: createCompanion) {
                            HStack {
                                if isCreating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18))
                                }
                                
                                Text(isCreating ? "Creating..." : "Create Companion")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(isCreating ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.secondary)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                        }
                        .disabled(isCreating || name.isEmpty || description.isEmpty || selectedExpertise.isEmpty)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.bottom, DesignSystem.Spacing.xl)
                    }
                }
            }
            .navigationTitle("Create Companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createCompanion() {
        guard !name.isEmpty && !description.isEmpty && !selectedExpertise.isEmpty else { return }
        
        isCreating = true
        
        companionService.createCompanion(
            name: name,
            description: description,
            personality: selectedCommunicationStyle,
            expertise: Array(selectedExpertise)
        ) { success, error in
            isCreating = false
            
            if success {
                dismiss()
            } else {
                errorMessage = error ?? "Failed to create companion"
                showError = true
            }
        }
    }
    
    private func getCommunicationStyleDescription(_ style: CompanionPersonality.CommunicationStyle) -> String {
        switch style {
        case .formal:
            return "Professional and structured"
        case .casual:
            return "Relaxed and informal"
        case .technical:
            return "Detailed and precise"
        case .creative:
            return "Imaginative and expressive"
        case .friendly:
            return "Warm and approachable"
        case .professional:
            return "Business-focused"
        }
    }
}

/// View for companion marketplace
struct CompanionMarketplaceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var marketplace = CompanionMarketplace()
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    
    private let categories = ["All", "Finance", "Technology", "Health", "Creativity", "Education", "Entertainment", "Business", "Personal"]
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Search and Filter
                    VStack(spacing: DesignSystem.Spacing.md) {
                        TextField("Search companions...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(categories, id: \.self) { category in
                                    Button(action: {
                                        selectedCategory = selectedCategory == category ? nil : category
                                    }) {
                                        Text(category)
                                            .font(DesignSystem.Typography.bodySmall)
                                            .foregroundColor(selectedCategory == category ? .white : DesignSystem.Colors.text)
                                            .padding(.horizontal, DesignSystem.Spacing.md)
                                            .padding(.vertical, DesignSystem.Spacing.sm)
                                            .background(selectedCategory == category ? DesignSystem.Colors.secondary : DesignSystem.Colors.surface)
                                            .cornerRadius(DesignSystem.CornerRadius.small)
                                    }
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    // Marketplace Content
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignSystem.Spacing.md) {
                            ForEach(marketplace.availableTemplates) { template in
                                CompanionTemplateCard(template: template)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                }
            }
            .navigationTitle("Companion Marketplace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            marketplace.loadTemplates()
        }
    }
}

/// Card for companion template in marketplace
struct CompanionTemplateCard: View {
    let template: CompanionTemplate
    @State private var showDetails = false
    
    var body: some View {
        Button(action: {
            showDetails = true
        }) {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.secondary)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                
                // Info
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text(template.name)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.text)
                        .lineLimit(2)
                    
                    Text(template.description)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                    
                    HStack {
                        Text("\(template.price) TLS")
                            .font(DesignSystem.Typography.bodySmall)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", template.rating))
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surface)
            .cornerRadius(DesignSystem.CornerRadius.medium)
        }
        .sheet(isPresented: $showDetails) {
            CompanionTemplateDetailView(template: template)
        }
    }
}

/// Detailed view for companion template
struct CompanionTemplateDetailView: View {
    let template: CompanionTemplate
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.secondary)
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Text(template.name)
                                .font(DesignSystem.Typography.titleLarge)
                                .foregroundColor(DesignSystem.Colors.text)
                            
                            Text(template.description)
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, DesignSystem.Spacing.xl)
                    
                    // Personality Details
                    CardView {
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Text("Personality")
                                .font(DesignSystem.Typography.titleSmall)
                                .foregroundColor(DesignSystem.Colors.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                DetailRow(title: "Communication Style", value: template.personality.communicationStyle.rawValue.capitalized)
                                DetailRow(title: "Expertise Areas", value: template.personality.expertiseAreas.map { $0.rawValue.capitalized }.joined(separator: ", "))
                                DetailRow(title: "Emotional Tone", value: template.personality.emotionalTone.rawValue.capitalized)
                                DetailRow(title: "Response Length", value: template.personality.responseLength.rawValue.capitalized)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    // Tags
                    CardView {
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Text("Tags")
                                .font(DesignSystem.Typography.titleSmall)
                                .foregroundColor(DesignSystem.Colors.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: DesignSystem.Spacing.sm) {
                                ForEach(template.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .padding(.horizontal, DesignSystem.Spacing.sm)
                                        .padding(.vertical, DesignSystem.Spacing.xs)
                                        .background(DesignSystem.Colors.background)
                                        .cornerRadius(DesignSystem.CornerRadius.small)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    // Purchase Button
                    Button(action: purchaseTemplate) {
                        HStack {
                            if isPurchasing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 18))
                            }
                            
                            Text(isPurchasing ? "Purchasing..." : "Purchase for \(template.price) TLS")
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(isPurchasing ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.secondary)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                    .disabled(isPurchasing)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Companion Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func purchaseTemplate() {
        isPurchasing = true
        
        // In a real implementation, this would handle the purchase
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isPurchasing = false
            dismiss()
        }
    }
}

/// Helper view for detail rows
struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.text)
        }
    }
}

/// Settings view for companion management
struct CompanionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var companionService = ZeroaAICompanion.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Settings content would go here
                        Text("Companion Settings")
                            .font(DesignSystem.Typography.titleLarge)
                            .foregroundColor(DesignSystem.Colors.text)
                            .padding(.top, DesignSystem.Spacing.xl)
                        
                        // Add settings options here
                    }
                }
            }
            .navigationTitle("Settings")
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