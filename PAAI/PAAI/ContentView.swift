import SwiftUI
import EventKit
import MapKit
import Combine

// MARK: - Models
struct Message: Identifiable, Codable {
    let id: String
    let contact: String
    let content: String
    let timestamp: String
    let viewed: Bool
    let priority: Int
}

struct BlockchainStats: Codable {
    let chain: String
    let blockHeight: Int
    let lastBlockHash: String
    let networkHashrate: Double

    enum CodingKeys: String, CodingKey {
        case chain
        case blockHeight = "block_height"
        case lastBlockHash = "last_block_hash"
        case networkHashrate = "network_hashrate"
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var address = ""
    @State private var mnemonic = ""
    @State private var isCheckingLogin = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var path = NavigationPath()
    @StateObject private var assistantService = AssistantService.shared
    @StateObject private var tlsService = TLSBlockchainService.shared

    private let walletService = WalletService.shared

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // Background
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.xl) {
                    Spacer()
                    
                    // Logo and Branding
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Image("ZeroaBanner")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 80)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        Text("PAAI")
                            .font(DesignSystem.Typography.titleLarge)
                            .foregroundColor(DesignSystem.Colors.text)
                        
                        Text("Your AI Assistant")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Login Form
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        InputField("Enter Wallet Address", text: $address)
                        InputField("Enter Mnemonic", text: $mnemonic, isSecure: true)
                        
                        PrimaryButton("Sign In", isLoading: isCheckingLogin) {
                            handleSignIn()
                        }
                        
                        SecondaryButton("Create New Account") {
                            path.append("create")
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    Spacer()
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .navigationDestination(for: String.self) { value in
                switch value {
                case "home":
                    HomeView(path: $path, assistantService: assistantService, tlsService: tlsService)
                case "create":
                    CreateAccountView(path: $path)
                case "prioritization":
                    PrioritizationView(messages: [], path: $path)
                case "stats":
                    StatsView(path: $path)
                case "userPortal":
                    UserPortalView(path: $path)
                default:
                    EmptyView()
                }
            }
            .onAppear {
                checkAutoLogin()
            }
        }
    }

    private func handleSignIn() {
        guard !isCheckingLogin else { return }
        isCheckingLogin = true
        
        if address.isEmpty || mnemonic.isEmpty {
            errorMessage = "Both address and mnemonic are required"
            showError = true
            isCheckingLogin = false
            return
        }
        
        walletService.importMnemonic(mnemonic) { success, derivedAddress in
            if success, derivedAddress == address {
                path.append("home")
            } else {
                errorMessage = "Invalid address or mnemonic"
                showError = true
            }
            isCheckingLogin = false
        }
    }

    private func checkAutoLogin() {
        guard !isCheckingLogin else { return }
        isCheckingLogin = true
        
        if let savedAddress = walletService.loadAddress(),
           let savedMnemonic = walletService.keychain.read(key: "wallet_mnemonic") {
            walletService.importMnemonic(savedMnemonic) { success, derivedAddress in
                if success, derivedAddress == savedAddress {
                    path.append("home")
                }
                isCheckingLogin = false
            }
        } else {
            isCheckingLogin = false
        }
    }
}

// MARK: - Create Account View
struct CreateAccountView: View {
    @Binding var path: NavigationPath
    @State private var mnemonic = ""
    @State private var hasWrittenDown = false
    @State private var showMnemonic = false
    @State private var showConfirm = false
    @State private var isCreating = false
    private let walletService = WalletService.shared

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Header
                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("Create Account")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Text("Write down your recovery phrase")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DesignSystem.Spacing.xxl)
                
                Spacer()
                
                // Mnemonic Display
                CardView {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Text(showMnemonic ? mnemonic : String(repeating: "•", count: 32))
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.text)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                Button(action: { showMnemonic.toggle() }) {
                                    Image(systemName: showMnemonic ? "eye.slash" : "eye")
                                        .foregroundColor(DesignSystem.Colors.secondary)
                                        .font(.system(size: 20))
                                }
                                
                                Button(action: {
                                    UIPasteboard.general.string = mnemonic
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(DesignSystem.Colors.secondary)
                                        .font(.system(size: 20))
                                }
                            }
                        }
                        
                        Text("Tap to show/hide • Copy to clipboard")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                
                // Confirmation Toggle
                Toggle("I have written this down securely", isOn: $hasWrittenDown)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.text)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                
                // Action Buttons
                VStack(spacing: DesignSystem.Spacing.md) {
                    PrimaryButton("Create Account", isLoading: isCreating) {
                        showConfirm = true
                    }
                    .disabled(!hasWrittenDown)
                    
                    SecondaryButton("Back to Login") {
                        path = NavigationPath()
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .alert("Confirm Account Creation", isPresented: $showConfirm) {
            Button("Create Account") {
                createAccount()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to create this account? Make sure you've written down your recovery phrase.")
        }
        .onAppear {
            mnemonic = walletService.generateMnemonic()
        }
    }
    
    private func createAccount() {
        isCreating = true
        walletService.importMnemonic(mnemonic) { success, _ in
            isCreating = false
            if success {
                path = NavigationPath()
            }
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @Binding var path: NavigationPath
    @ObservedObject var assistantService: AssistantService
    @ObservedObject var tlsService: TLSBlockchainService
    @State private var commandInput = ""
    @State private var isSubscribed = false
    @State private var isInitializing = false
    @State private var showSubscriptionAlert = false
    @State private var showLogoutAlert = false
    @State private var chain: String?
    @State private var blockHeight: Int?
    @State private var lastBlockHash: String?
    @State private var networkHashrate: Double?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var prioritizedMessages: [Message] = []
    private let walletService = WalletService.shared
    private let networkService = NetworkService.shared

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Welcome back")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text(walletService.loadAddress() ?? "Unknown")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.text)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button("Sign Message") {
                            commandInput = "sign message Hello"
                            handleCommand()
                        }
                        Button("Prioritize Messages") {
                            commandInput = "prioritize messages"
                            handleCommand()
                        }
                        Button("Blockchain Stats") {
                            commandInput = "tell main stats"
                            handleCommand()
                        }
                        Button("Logout", role: .destructive) {
                            showLogoutAlert = true
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(DesignSystem.Colors.text)
                            .font(.system(size: 20))
                            .padding(DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.surface)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.lg)
                
                if isInitializing {
                    LoadingView(message: "Initializing...")
                } else if !isSubscribed {
                    subscriptionView
                } else {
                    mainContentView
                }
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .alert("Success", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Logout", role: .destructive) {
                logout()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .onAppear {
            initialize()
        }
    }
    
    private var subscriptionView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundColor(DesignSystem.Colors.secondary)
                
                Text("Subscription Required")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.text)
                
                Text("To access AI services, please complete your subscription payment.")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: DesignSystem.Spacing.md) {
                    PrimaryButton("Pay with TLS", isLoading: false) {
                        Task {
                            await processSubscription()
                        }
                    }
                    
                    Text("10 TLS / month")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(DesignSystem.Spacing.xl)
            
            Spacer()
        }
    }
    
    private var mainContentView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // AI Chat Interface
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    InputField("How may I help you?", text: $commandInput)
                    
                    Button(action: {
                        handleCommand()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 18))
                            .padding(DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.secondary)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                
                // Blockchain Stats Card
                if let chain = chain, let blockHeight = blockHeight,
                   let lastBlockHash = lastBlockHash, let networkHashrate = networkHashrate {
                    CardView {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Blockchain Stats")
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(DesignSystem.Colors.text)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Chain: \(chain)")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Text("Block Height: \(blockHeight)")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Text("Hashrate: \(String(format: "%.2f", networkHashrate)) GH/s")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }
            
            Spacer()
        }
    }
    
    private func initialize() {
        guard !isInitializing else { return }
        isInitializing = true
        
        walletService.initialize {
            isSubscribed = walletService.checkSubscription()
            fetchBlockchainInfo()
            loadAndPrioritizeMessages()
            Task {
                await tlsService.refreshBalance()
            }
            isInitializing = false
        }
    }
    
    private func processSubscription() async {
        let success = await tlsService.processSubscriptionPayment()
        await MainActor.run {
            if success {
                isSubscribed = true
                alertMessage = "Subscription activated successfully!"
                showAlert = true
            } else {
                alertMessage = "Payment failed. Please try again."
                showAlert = true
            }
        }
    }
    
    private func logout() {
        walletService.clear()
        path = NavigationPath()
    }

    private func fetchBlockchainInfo() {
        guard let statsURL = URL(string: "https://telestai.cryptoscope.io/api/stats/") else {
            DispatchQueue.main.async {
                self.chain = "Main"
                self.blockHeight = 123456
                self.lastBlockHash = "abc123..."
                self.networkHashrate = 100.50
            }
            return
        }
        
        URLSession.shared.dataTask(with: statsURL) { data, response, error in
            if let error = error {
                print("Stats fetch error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.chain = "Main"
                    self.blockHeight = 123456
                    self.lastBlockHash = "abc123..."
                    self.networkHashrate = 100.50
                }
                return
            }
            
            guard let data = data,
                  let stats = try? JSONDecoder().decode(BlockchainStats.self, from: data) else {
                DispatchQueue.main.async {
                    self.chain = "Main"
                    self.blockHeight = 123456
                    self.lastBlockHash = "abc123..."
                    self.networkHashrate = 100.50
                }
                return
            }
            
            DispatchQueue.main.async {
                self.chain = stats.chain
                self.blockHeight = stats.blockHeight
                self.lastBlockHash = stats.lastBlockHash
                self.networkHashrate = stats.networkHashrate / 1e9
            }
        }.resume()
    }

    private func loadAndPrioritizeMessages() {
        let newMessages: [Message] = [
            Message(id: UUID().uuidString, contact: "John", content: "Meeting at 3 PM", timestamp: "2025-07-14T00:00:00Z", viewed: false, priority: 0),
            Message(id: UUID().uuidString, contact: "Boss", content: "URGENT: Review report", timestamp: "2025-07-14T00:05:00Z", viewed: false, priority: 0),
            Message(id: UUID().uuidString, contact: "Mom", content: "Call me back", timestamp: "2025-07-14T00:10:00Z", viewed: false, priority: 0)
        ]
        
        var contactRanks = ["John": 5, "Boss": 10, "Mom": 3]
        if let ranksData = walletService.keychain.read(key: "contact_ranks"),
           let ranks = try? JSONSerialization.jsonObject(with: Data(ranksData.utf8)) as? [String: Int] {
            contactRanks = ranks
        } else {
            if let ranksData = try? JSONSerialization.data(withJSONObject: contactRanks) {
                _ = walletService.keychain.save(key: "contact_ranks", value: String(data: ranksData, encoding: .utf8)!)
            }
        }
        
        prioritizedMessages = newMessages.map { msg in
            let baseRank = contactRanks[msg.contact] ?? 1
            let urgencyRank = msg.content.lowercased().contains("urgent") ? 20 : 0
            return Message(id: msg.id, contact: msg.contact, content: msg.content, timestamp: msg.timestamp, viewed: msg.viewed, priority: baseRank + urgencyRank)
        }.sorted { $0.priority > $1.priority }
        
        if let messagesData = try? JSONSerialization.data(withJSONObject: prioritizedMessages.map { [
            "id": $0.id,
            "contact": $0.contact,
            "content": $0.content,
            "timestamp": $0.timestamp,
            "viewed": $0.viewed,
            "priority": $0.priority
        ]}) {
            _ = walletService.keychain.save(key: "prioritized_messages", value: String(data: messagesData, encoding: .utf8)!)
        }
    }

    private func handleCommand() {
        guard isSubscribed, !commandInput.isEmpty else {
            if !isSubscribed {
                showSubscriptionAlert = true
            } else {
                alertMessage = "Please enter a command"
                showAlert = true
            }
            assistantService.speak("Subscription required or empty input")
            return
        }
        
        let enhancedPrompt = """
        Parse this command: "\(commandInput)". 
        
        Identify the action and return a JSON object with:
        - "action": string (e.g., "add meeting", "schedule meeting", "open maps", "open safari", "prioritize messages", "tell main stats", "sign message", "open user portal", "toggle stream", "check balance", "send payment")
        - "parameters": object with relevant data (e.g., "title", "start", "end" for meetings, "location" for maps, "url" for safari, "message" for sign message, "amount" for payments)
        
        Use UTC timezone and assume today is 2025-07-15. Provide helpful, contextual responses.
        """
        
        print("Sending enhanced AI request: \(enhancedPrompt)")
        networkService.getGrokResponse(input: enhancedPrompt) { result in
            print("Enhanced AI result: \(result)")
            switch result {
            case .success(let response):
                assistantService.speak(response)
                if let data = response.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let action = json["action"] as? String {
                    print("Parsed action: \(action), json: \(json)")
                    handleAction(action: action, parameters: json)
                }
            case .failure(let error):
                print("AI request failed: \(error)")
                assistantService.speak("I'm sorry, I couldn't process that request. Please try again.")
            }
        }
    }
    
    private func handleAction(action: String, parameters: [String: Any]) {
        switch action {
        case "add meeting", "schedule meeting":
            if let title = parameters["title"] as? String,
               let start = parameters["start"] as? String,
               let end = parameters["end"] as? String,
               let startDate = ISO8601DateFormatter().date(from: start),
               let endDate = ISO8601DateFormatter().date(from: end) {
                addToCalendar(title: title, start: startDate, end: endDate)
            } else {
                assistantService.speak("I couldn't understand the meeting details. Please try again.")
                alertMessage = "Invalid meeting details"
                showAlert = true
            }
        case "open maps":
            if let location = parameters["location"] as? String {
                openMaps(location: location)
            }
        case "open safari":
            if let url = parameters["url"] as? String {
                openURL(url: url)
            }
        case "prioritize messages":
            loadAndPrioritizeMessages()
            path.append("prioritization")
        case "tell main stats":
            fetchBlockchainInfo()
            path.append("stats")
        case "sign message":
            if let message = parameters["message"] as? String,
               let signature = walletService.signMessage(message) {
                let response = "Signed: \(message) (Signature: \(signature))"
                assistantService.speak(response)
                alertMessage = response
                showAlert = true
            }
        case "check balance":
            Task {
                await tlsService.refreshBalance()
                await MainActor.run {
                    let balance = tlsService.formatBalance(tlsService.currentBalance)
                    assistantService.speak("Your current balance is \(balance)")
                    alertMessage = "Balance: \(balance)"
                    showAlert = true
                }
            }
        case "send payment":
            if let toAddress = parameters["to"] as? String,
               let amount = parameters["amount"] as? Double {
                Task {
                    let response = await tlsService.sendPayment(toAddress: toAddress, amount: amount)
                    await MainActor.run {
                        if response.success {
                            assistantService.speak("Payment sent successfully. Transaction ID: \(response.txid ?? "Unknown")")
                            alertMessage = "Payment successful! TXID: \(response.txid ?? "Unknown")"
                        } else {
                            assistantService.speak("Payment failed: \(response.error ?? "Unknown error")")
                            alertMessage = "Payment failed: \(response.error ?? "Unknown error")"
                        }
                        showAlert = true
                    }
                }
            }
        default:
            assistantService.speak("I understand you want to \(action). Let me help you with that.")
        }
    }

    private func addToCalendar(title: String, start: Date, end: Date) {
        let eventStore = EKEventStore()
        eventStore.requestAccess(to: .event) { granted, error in
            if granted {
                let event = EKEvent(eventStore: eventStore)
                event.title = title
                event.startDate = start
                event.endDate = end
                event.calendar = eventStore.defaultCalendarForNewEvents
                
                do {
                    try eventStore.save(event, span: .thisEvent)
                    DispatchQueue.main.async {
                        self.assistantService.speak("Event added: \(title)")
                        self.alertMessage = "Event added: \(title)"
                        self.showAlert = true
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.assistantService.speak("Failed to add event")
                        self.alertMessage = "Failed to add event"
                        self.showAlert = true
                    }
                }
            }
        }
    }

    private func openMaps(location: String) {
        let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location
        if let url = URL(string: "http://maps.apple.com/?q=\(encodedLocation)") {
            UIApplication.shared.open(url)
        }
    }

    private func openURL(url: String) {
        guard let url = URL(string: url) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Supporting Views
struct PrioritizationView: View {
    let messages: [Message]
    @Binding var path: NavigationPath
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack {
                Text("Message Prioritization")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.text)
                    .padding()
                
                Spacer()
                
                Text("Coming Soon")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
}

struct StatsView: View {
    @Binding var path: NavigationPath
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack {
                Text("Blockchain Stats")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.text)
                    .padding()
                
                Spacer()
                
                Text("Coming Soon")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
}

struct UserPortalView: View {
    @Binding var path: NavigationPath
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack {
                Text("User Portal")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.text)
                    .padding()
                
                Spacer()
                
                Text("Coming Soon")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Extensions
struct DisableInputAccessoryView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        return UIView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension View {
    func disableInputAccessoryView() -> some View {
        self.background(DisableInputAccessoryView())
    }
}
