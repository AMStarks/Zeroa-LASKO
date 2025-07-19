import SwiftUI
import Combine

// MARK: - Adaptive AI Companion Views

/// Main adaptive companion management view
struct AdaptiveCompanionManagementView: View {
    @StateObject private var companionService = AdaptiveAICompanion.shared
    @State private var showCreateCompanion = false
    @State private var showInterventions = false
    @State private var showLearningData = false
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Text("Adaptive AI Companion")
                            .font(DesignSystem.Typography.titleLarge)
                            .foregroundColor(DesignSystem.Colors.text)
                        
                        Text("Your learning AI assistant")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.top, DesignSystem.Spacing.xl)
                    
                    // Current Companion Status
                    if let companion = companionService.currentCompanion {
                        AdaptiveCompanionCard(companion: companion)
                    } else {
                        NoAdaptiveCompanionCard {
                            showCreateCompanion = true
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: DesignSystem.Spacing.md) {
                        if companionService.currentCompanion != nil {
                            Button(action: {
                                showInterventions = true
                            }) {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 18))
                                    Text("Recent Interventions")
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
                                showLearningData = true
                            }) {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: 18))
                                    Text("Learning Data")
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(DesignSystem.Colors.text)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.md)
                                .background(DesignSystem.Colors.surface)
                                .cornerRadius(DesignSystem.CornerRadius.medium)
                            }
                            
                            // Monitoring Status
                            HStack {
                                Circle()
                                    .fill(companionService.isMonitoring ? DesignSystem.Colors.success : DesignSystem.Colors.error)
                                    .frame(width: 12, height: 12)
                                
                                Text(companionService.isMonitoring ? "Monitoring Active" : "Monitoring Inactive")
                                    .font(DesignSystem.Typography.bodySmall)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    if companionService.isMonitoring {
                                        companionService.stopMonitoring()
                                    } else {
                                        companionService.startMonitoring()
                                    }
                                }) {
                                    Text(companionService.isMonitoring ? "Stop" : "Start")
                                        .font(DesignSystem.Typography.bodySmall)
                                        .foregroundColor(DesignSystem.Colors.secondary)
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showCreateCompanion) {
            CreateAdaptiveCompanionView()
        }
        .sheet(isPresented: $showInterventions) {
            InterventionsView()
        }
        .sheet(isPresented: $showLearningData) {
            LearningDataView()
        }
    }
}

/// Card showing current adaptive companion information
struct AdaptiveCompanionCard: View {
    let companion: AdaptiveCompanion
    
    var body: some View {
        CardView {
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text(companion.name)
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.text)
                        
                        Text(companion.initialDescription)
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
                        
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                
                // Learning Status
                VStack(spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("Learning Rate")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text("\(Int(companion.currentPersonality.learningRate * 100))%")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.text)
                    }
                    
                    HStack {
                        Text("Intervention Style")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text(companion.currentPersonality.interventionStyle.rawValue.capitalized)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.text)
                    }
                    
                    HStack {
                        Text("Patterns Learned")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text("\(companion.learningData.userBehaviorPatterns.count)")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.text)
                    }
                    
                    HStack {
                        Text("Last Interaction")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text(formatDate(companion.lastInteractionDate))
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.text)
                    }
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Card shown when no adaptive companion is created
struct NoAdaptiveCompanionCard: View {
    let onCreateCompanion: () -> Void
    
    var body: some View {
        CardView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundColor(DesignSystem.Colors.secondary)
                
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("No Adaptive AI Companion")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Text("Create an AI companion that learns from your behavior and provides proactive suggestions")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                Button(action: onCreateCompanion) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 18))
                        Text("Create Adaptive Companion")
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

/// View for creating a new adaptive AI companion
struct CreateAdaptiveCompanionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var companionService = AdaptiveAICompanion.shared
    
    @State private var name = ""
    @State private var description = ""
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
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 48))
                                .foregroundColor(DesignSystem.Colors.secondary)
                            
                            Text("Create Adaptive AI Companion")
                                .font(DesignSystem.Typography.titleLarge)
                                .foregroundColor(DesignSystem.Colors.text)
                            
                            Text("Your AI companion will learn from your behavior and provide proactive suggestions")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, DesignSystem.Spacing.xl)
                        
                        // Form
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            // Name Field
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Companion Name")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(DesignSystem.Colors.text)
                                
                                TextField("Enter companion name", text: $name)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(DesignSystem.Typography.bodyMedium)
                            }
                            
                            // Description Field
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Description")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(DesignSystem.Colors.text)
                                
                                Text("Describe the type of AI companion you want. The companion will learn and adapt based on your behavior.")
                                    .font(DesignSystem.Typography.bodySmall)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                TextEditor(text: $description)
                                    .frame(minHeight: 100)
                                    .padding(DesignSystem.Spacing.sm)
                                    .background(DesignSystem.Colors.surface)
                                    .cornerRadius(DesignSystem.CornerRadius.small)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                    )
                            }
                            
                            // Features Preview
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                Text("What your companion will do:")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(DesignSystem.Colors.text)
                                
                                VStack(spacing: DesignSystem.Spacing.sm) {
                                    FeatureRow(icon: "eye.fill", title: "Monitor your actions", description: "Learn from your behavior patterns")
                                    FeatureRow(icon: "lightbulb.fill", title: "Provide suggestions", description: "Offer proactive recommendations")
                                    FeatureRow(icon: "brain.head.profile", title: "Adapt personality", description: "Evolve based on your preferences")
                                    FeatureRow(icon: "shield.fill", title: "Security insights", description: "Alert you to potential risks")
                                }
                            }
                            .padding(DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.surface)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        // Create Button
                        Button(action: createCompanion) {
                            HStack {
                                if isCreating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18))
                                }
                                
                                Text(isCreating ? "Creating..." : "Create Adaptive Companion")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(name.isEmpty || description.isEmpty ? DesignSystem.Colors.disabled : DesignSystem.Colors.secondary)
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                        }
                        .disabled(name.isEmpty || description.isEmpty || isCreating)
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
                    .foregroundColor(DesignSystem.Colors.secondary)
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
        isCreating = true
        
        companionService.createAdaptiveCompanion(
            name: name,
            description: description
        ) { success, error in
            DispatchQueue.main.async {
                isCreating = false
                
                if success {
                    dismiss()
                } else {
                    errorMessage = error ?? "Unknown error occurred"
                    showError = true
                }
            }
        }
    }
}

/// Feature row for the creation view
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(DesignSystem.Colors.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.text)
                
                Text(description)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

/// View for displaying recent interventions
struct InterventionsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var companionService = AdaptiveAICompanion.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                if companionService.recentInterventions.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text("No Interventions Yet")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.text)
                        
                        Text("Your AI companion will suggest interventions as it learns from your behavior")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                } else {
                    ScrollView {
                        LazyVStack(spacing: DesignSystem.Spacing.md) {
                            ForEach(companionService.recentInterventions, id: \.id) { intervention in
                                InterventionCard(intervention: intervention) { response in
                                    companionService.recordInterventionResponse(intervention.id, response: response)
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.top, DesignSystem.Spacing.lg)
                    }
                }
            }
            .navigationTitle("Recent Interventions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.secondary)
                }
            }
        }
    }
}

/// Card for displaying an intervention
struct InterventionCard: View {
    let intervention: ProactiveIntervention
    let onResponse: (ProactiveIntervention.UserResponse) -> Void
    
    @State private var showingActions = false
    
    var body: some View {
        CardView {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Header
                HStack {
                    Image(systemName: iconForInterventionType(intervention.interventionType))
                        .font(.system(size: 20))
                        .foregroundColor(colorForUrgency(intervention.urgency))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(intervention.interventionType.rawValue.capitalized)
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.text)
                        
                        Text(formatDate(intervention.timestamp))
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    UrgencyBadge(urgency: intervention.urgency)
                }
                
                // Message
                Text(intervention.message)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.text)
                    .multilineTextAlignment(.leading)
                
                // Suggested Actions
                if let suggestedActions = intervention.suggestedActions, !suggestedActions.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Suggested Actions:")
                            .font(DesignSystem.Typography.bodySmall)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        ForEach(suggestedActions, id: \.self) { action in
                            HStack {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                Text(action)
                                    .font(DesignSystem.Typography.bodySmall)
                                    .foregroundColor(DesignSystem.Colors.text)
                            }
                        }
                    }
                }
                
                // Response Buttons
                if intervention.userResponse == nil {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Button("Accept") {
                            onResponse(.accepted)
                        }
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.success)
                        .cornerRadius(DesignSystem.CornerRadius.small)
                        
                        Button("Dismiss") {
                            onResponse(.dismissed)
                        }
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.text)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.surface)
                        .cornerRadius(DesignSystem.CornerRadius.small)
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(intervention.userResponse == .accepted ? DesignSystem.Colors.success : DesignSystem.Colors.textSecondary)
                        
                        Text(intervention.userResponse?.rawValue.capitalized ?? "")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
    }
    
    private func iconForInterventionType(_ type: AdaptiveCompanion.CompanionLearningData.InteractionRecord.InterventionType) -> String {
        switch type {
        case .suggestion: return "lightbulb.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .alternative: return "arrow.triangle.branch"
        case .optimization: return "speedometer"
        case .security: return "shield.fill"
        }
    }
    
    private func colorForUrgency(_ urgency: ProactiveIntervention.Urgency) -> Color {
        switch urgency {
        case .low: return DesignSystem.Colors.success
        case .medium: return DesignSystem.Colors.warning
        case .high: return DesignSystem.Colors.error
        case .critical: return .red
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Badge showing intervention urgency
struct UrgencyBadge: View {
    let urgency: ProactiveIntervention.Urgency
    
    var body: some View {
        Text(urgency.rawValue.capitalized)
            .font(DesignSystem.Typography.bodySmall)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, 4)
            .background(colorForUrgency(urgency))
            .cornerRadius(DesignSystem.CornerRadius.small)
    }
    
    private func colorForUrgency(_ urgency: ProactiveIntervention.Urgency) -> Color {
        switch urgency {
        case .low: return DesignSystem.Colors.success
        case .medium: return DesignSystem.Colors.warning
        case .high: return DesignSystem.Colors.error
        case .critical: return .red
        }
    }
}

/// View for displaying learning data
struct LearningDataView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var companionService = AdaptiveAICompanion.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        if let companion = companionService.currentCompanion {
                            // Behavior Patterns
                            LearningDataSection(
                                title: "Behavior Patterns",
                                icon: "chart.line.uptrend.xyaxis"
                            ) {
                                ForEach(Array(companion.learningData.userBehaviorPatterns.values.prefix(10)), id: \.pattern) { pattern in
                                    BehaviorPatternRow(pattern: pattern)
                                }
                            }
                            
                            // Topic Engagement
                            LearningDataSection(
                                title: "Topic Engagement",
                                icon: "brain.head.profile"
                            ) {
                                ForEach(Array(companion.learningData.topicEngagement.sorted(by: { $0.value > $1.value }).prefix(5)), id: \.key) { topic, engagement in
                                    TopicEngagementRow(topic: topic, engagement: engagement)
                                }
                            }
                            
                            // Intervention Effectiveness
                            LearningDataSection(
                                title: "Intervention Effectiveness",
                                icon: "lightbulb.fill"
                            ) {
                                ForEach(Array(companion.learningData.interventionEffectiveness.sorted(by: { $0.value > $1.value }).prefix(5)), id: \.key) { interventionId, effectiveness in
                                    InterventionEffectivenessRow(interventionId: interventionId, effectiveness: effectiveness)
                                }
                            }
                        } else {
                            Text("No learning data available")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Learning Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.secondary)
                }
            }
        }
    }
}

/// Section for learning data
struct LearningDataSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(DesignSystem.Colors.secondary)
                
                Text(title)
                    .font(DesignSystem.Typography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.text)
                
                Spacer()
            }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                content
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
}

/// Row for behavior pattern
struct BehaviorPatternRow: View {
    let pattern: AdaptiveCompanion.CompanionLearningData.BehaviorPattern
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(pattern.pattern)
                    .font(DesignSystem.Typography.bodySmall)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.text)
                
                Text("Frequency: \(pattern.frequency)")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            if let response = pattern.userResponse {
                Text(response.rawValue.capitalized)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(colorForResponse(response))
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
    
    private func colorForResponse(_ response: AdaptiveCompanion.CompanionLearningData.BehaviorPattern.UserResponse) -> Color {
        switch response {
        case .positive: return DesignSystem.Colors.success
        case .negative: return DesignSystem.Colors.error
        case .neutral: return DesignSystem.Colors.textSecondary
        case .ignored: return DesignSystem.Colors.textSecondary
        }
    }
}

/// Row for topic engagement
struct TopicEngagementRow: View {
    let topic: String
    let engagement: Double
    
    var body: some View {
        HStack {
            Text(topic.capitalized)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.text)
            
            Spacer()
            
            Text("\(Int(engagement * 100))%")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
}

/// Row for intervention effectiveness
struct InterventionEffectivenessRow: View {
    let interventionId: String
    let effectiveness: Double
    
    var body: some View {
        HStack {
            Text(interventionId.prefix(8) + "...")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.text)
            
            Spacer()
            
            Text(String(format: "%.1f", effectiveness))
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(effectiveness > 0 ? DesignSystem.Colors.success : DesignSystem.Colors.error)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
} 