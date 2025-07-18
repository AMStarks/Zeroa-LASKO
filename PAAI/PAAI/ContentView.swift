import SwiftUI
import Combine
import EventKit
import MapKit
import WebKit

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

struct CoinGeckoPrice: Codable {
    let telestai: TLSPriceData
}

struct TLSPriceData: Codable {
    let usd: Double
    let usd_24h_change: Double
    let last_updated_at: Int?
}

struct SessionInfo: Identifiable {
    let id = UUID()
    let deviceName: String
    let location: String
    let lastActive: Date
    let isCurrent: Bool
}

struct AnalyticsData {
    let totalTransactions: Int
    let totalVolume: Double
    let averageTransactionSize: Double
    let mostUsedFeatures: [String: Int]
    let dailyActiveMinutes: Int
    let weeklyUsage: [String: Int]
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
    @StateObject private var messagingService = MessagingService.shared
    
    // Messaging state variables
    @State private var conversations: [ChatConversation] = []
    @State private var currentConversation: ChatConversation?
    @State private var messageText = ""
    @State private var showNewChat = false
    @State private var newContactName = ""
    @State private var newContactAddress = ""
    
    // Sheet state variables
    @State private var showSubscriptionAlert = false
    @State private var showSendSheet = false
    @State private var showReceiveSheet = false
    @State private var showTransactionsSheet = false
    @State private var showMessaging = false
    @State private var showHamburgerMenu = false
    @State private var selectedTab = 0

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
                        
                        SecondaryButton(title: "Create New Account") {
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
                    StatsView()
                case "userPortal":
                    UserPortalView(path: $path)
                case "profile":
                    ProfileView(path: $path)
                case "messaging":
                    ConversationsListView(
                        conversations: $conversations,
                        currentConversation: $currentConversation,
                        showNewChat: $showNewChat
                    )
                default:
                    EmptyView()
                }
            }
            .onAppear {
                checkAutoLogin()
            }
        }
        .sheet(isPresented: $showSubscriptionAlert) {
            SubscriptionView()
        }
        .sheet(isPresented: $showSendSheet) {
            SendView()
        }
        .sheet(isPresented: $showReceiveSheet) {
            ReceiveView()
        }
        .sheet(isPresented: $showTransactionsSheet) {
            TransactionsView()
        }
        .sheet(isPresented: $showMessaging) {
            ConversationsListView(
                conversations: $conversations,
                currentConversation: $currentConversation,
                showNewChat: $showNewChat
            )
        }
        .sheet(isPresented: $showNewChat) {
            NewChatView(
                newContactName: $newContactName,
                newContactAddress: $newContactAddress,
                conversations: $conversations
            )
        }
        .sheet(item: $currentConversation) { conversation in
            ChatView(
                conversation: Binding(
                    get: { conversation },
                    set: { newValue in
                        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
                            conversations[index] = newValue
                        }
                    }
                ),
                messageText: $messageText
            )
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
    @State private var address = ""
    @State private var mnemonic = ""
    @State private var confirmMnemonic = ""
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let walletService = WalletService.shared
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Header
                HStack {
                    Button("Back") {
                        path.removeLast()
                    }
                    .foregroundColor(DesignSystem.Colors.secondary)
                    
                    Spacer()
                    
                    Text("Create Account")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.lg)
                
                Spacer()
                
                // Form
                VStack(spacing: DesignSystem.Spacing.lg) {
                    InputField("Enter Wallet Address", text: $address)
                    InputField("Enter Mnemonic", text: $mnemonic, isSecure: true)
                    InputField("Confirm Mnemonic", text: $confirmMnemonic, isSecure: true)
                    
                    PrimaryButton("Create Account", isLoading: isCreating) {
                        createAccount()
                    }
                    .disabled(address.isEmpty || mnemonic.isEmpty || confirmMnemonic.isEmpty || mnemonic != confirmMnemonic)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createAccount() {
        guard !isCreating else { return }
        isCreating = true
        
        if mnemonic != confirmMnemonic {
            errorMessage = "Mnemonics do not match"
            showError = true
            isCreating = false
            return
        }
        
        walletService.importMnemonic(mnemonic) { success, derivedAddress in
            if success, derivedAddress == address {
                path.append("home")
            } else {
                errorMessage = "Invalid address or mnemonic"
                showError = true
            }
            isCreating = false
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
    @State private var prioritizedMessages: [ChatMessage] = []
    @State private var tlsBalance: Double = 0.0
    @State private var tlsPrice: Double = 0.0
    @State private var tlsPriceChange: Double = 0.0
    @State private var isLoadingPrice = false
    @State private var priceHistory: [Double] = []
    @State private var isLoadingHistory = false
    
    // Personal Information
    @State private var profilePicture: UIImage?
    @State private var displayName = "PAAI User"
    @State private var userBio = ""
    @State private var userLocation = ""
    @State private var socialLinks: [String: String] = [:]
    
    // Security & Session
    @State private var biometricEnabled = true
    @State private var activeSessions: [SessionInfo] = []
    @State private var showSessionManagement = false
    
    // Preferences
    @State private var selectedLanguage = "English"
    @State private var selectedCurrency = "USD"
    @State private var selectedTheme = "Auto"
    @State private var availableLanguages = ["English", "Spanish", "French", "German", "Chinese"]
    @State private var availableCurrencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD"]
    @State private var availableThemes = ["Auto", "Light", "Dark"]
    
    // Analytics
    @State private var showAnalytics = false
    @State private var analyticsData: AnalyticsData?
    
    // Bug Reporting
    @State private var showBugReport = false
    @State private var bugDescription = ""
    @State private var bugCategory = "General"
    @State private var bugCategories = ["General", "AI Issues", "Payment Issues", "UI/UX", "Performance", "Security"]
    
    // Transaction Actions
    @State private var showSendSheet = false
    @State private var showReceiveSheet = false
    @State private var showTransactionsSheet = false
    
    // Bottom Navigation
    @State private var selectedTab = 0
    @State private var showMessaging = false
    @State private var showHamburgerMenu = false
    
    // BitChat Messaging
    @State private var conversations: [ChatConversation] = []
    @State private var currentConversation: ChatConversation?
    @State private var messageText = ""
    @State private var showNewChat = false
    @State private var newContactName = ""
    @State private var newContactAddress = ""
    
    private let walletService = WalletService.shared
    private let networkService = NetworkService.shared

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Header
                HStack {
                    Spacer()
                    
                    Text("PAAI")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.lg)
                
                // TLS Balance Section
                VStack(spacing: DesignSystem.Spacing.lg) {
                    CardView {
                        VStack(spacing: DesignSystem.Spacing.md) {
                            HStack {
                                Text("TLS Balance")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Spacer()
                                if isLoadingPrice {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                            
                            VStack(spacing: DesignSystem.Spacing.md) {
                                VStack(spacing: DesignSystem.Spacing.xs) {
                                    Text("\(Int(ceil(tlsBalance))) TLS")
                                        .font(DesignSystem.Typography.titleMedium)
                                        .foregroundColor(DesignSystem.Colors.text)
                                        .multilineTextAlignment(.center)
                                    
                                    if tlsPrice > 0 {
                                        Text("$\(String(format: "%.2f", tlsBalance * tlsPrice))")
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                
                                VStack(spacing: DesignSystem.Spacing.xs) {
                                    Text("7-Day Price Trend")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                    
                                    if isLoadingHistory {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    } else {
                                        LineChartView(data: priceHistory, width: 280, height: 60)
                                            .background(Color.clear)
                                    }
                                }
                            }
                            
                            if tlsPriceChange != 0 {
                                HStack {
                                    Image(systemName: tlsPriceChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                                        .foregroundColor(tlsPriceChange >= 0 ? .green : .red)
                                    Text("\(String(format: "%.2f", abs(tlsPriceChange)))%")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(tlsPriceChange >= 0 ? .green : .red)
                                    Spacer()
                                }
                            }
                            
                            // Transaction Action Buttons
                            HStack(spacing: DesignSystem.Spacing.md) {
                                Button(action: {
                                    showSendSheet = true
                                }) {
                                    VStack(spacing: DesignSystem.Spacing.sm) {
                                        ZStack {
                                            Circle()
                                                .fill(DesignSystem.Colors.secondary)
                                                .frame(width: 56, height: 56)
                                            
                                            Image(systemName: "arrow.up")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(.white)
                                        }
                                        
                                        Text("Send")
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .fontWeight(.semibold)
                                            .foregroundColor(DesignSystem.Colors.text)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DesignSystem.Spacing.md)
                                }
                                
                                Button(action: {
                                    showReceiveSheet = true
                                }) {
                                    VStack(spacing: DesignSystem.Spacing.sm) {
                                        ZStack {
                                            Circle()
                                                .fill(DesignSystem.Colors.secondary)
                                                .frame(width: 56, height: 56)
                                            
                                            Image(systemName: "arrow.down")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(.white)
                                        }
                                        
                                        Text("Receive")
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .fontWeight(.semibold)
                                            .foregroundColor(DesignSystem.Colors.text)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DesignSystem.Spacing.md)
                                }
                                
                                Button(action: {
                                    showTransactionsSheet = true
                                }) {
                                    VStack(spacing: DesignSystem.Spacing.sm) {
                                        ZStack {
                                            Circle()
                                                .fill(DesignSystem.Colors.secondary)
                                                .frame(width: 56, height: 56)
                                            
                                            Image(systemName: "clock.arrow.circlepath")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(.white)
                                        }
                                        
                                        Text("History")
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .fontWeight(.semibold)
                                            .foregroundColor(DesignSystem.Colors.text)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DesignSystem.Spacing.md)
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
                
                // AI Command Line
                VStack(spacing: DesignSystem.Spacing.xl) {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            InputField("How may I help you?", text: $commandInput)
                                .frame(maxWidth: .infinity)
                                .onSubmit {
                                    handleCommand()
                                }
                            
                            Button(action: {
                                handleCommand()
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18))
                                    .frame(width: 40, height: 40)
                                    .background(DesignSystem.Colors.primary)
                                    .clipShape(Circle())
                            }
                            .disabled(commandInput.isEmpty)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                    
                    // ZeroaFinger Image
                    Image("ZeroaFinger")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 120)
                        .padding(.vertical, DesignSystem.Spacing.xl)
                    
                    // Bottom Navigation
                    BottomNavigationView(
                        selectedTab: $selectedTab,
                        showMessaging: $showMessaging,
                        showHamburgerMenu: $showHamburgerMenu,
                        path: $path
                    )
                }
            }
        }
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
        .sheet(isPresented: $showHamburgerMenu) {
            HamburgerMenuView(showHamburgerMenu: $showHamburgerMenu, path: $path, showLogoutAlert: $showLogoutAlert)
        }
        .sheet(isPresented: $showSendSheet) {
            SendView()
        }
        .sheet(isPresented: $showReceiveSheet) {
            ReceiveView()
        }
        .sheet(isPresented: $showTransactionsSheet) {
            TransactionsView()
        }
        .onAppear {
            initialize()
        }
    }
    
    private func handleCommand() {
        guard !commandInput.isEmpty else { return }
        
        let response = assistantService.generateContextualResponse(to: commandInput, context: ["balance": tlsBalance])
        alertMessage = response
        showAlert = true
        commandInput = ""
    }
    
    private func initialize() {
        isInitializing = true
        
        Task {
            await loadTLSData()
            isInitializing = false
        }
    }
    
    private func loadTLSData() async {
        if let address = walletService.loadAddress(),
           let addressInfo = await tlsService.getAddressInfo(address: address) {
            tlsBalance = addressInfo.balance
        }
        tlsPrice = 0.0
        tlsPriceChange = 0.0
        priceHistory = []
        isLoadingPrice = false
        isLoadingHistory = false
    }
    
    private func logout() {
        walletService.keychain.delete(key: "wallet_mnemonic")
        path.removeLast(path.count)
    }
}



struct LineChartView: View {
    let data: [Double]
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard data.count > 1 else { return }
                
                let stepX = width / CGFloat(data.count - 1)
                let maxValue = data.max() ?? 1
                let minValue = data.min() ?? 0
                let range = maxValue - minValue
                
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalizedValue = range > 0 ? (value - minValue) / range : 0.5
                    let y = height * (1 - normalizedValue)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(DesignSystem.Colors.secondary, lineWidth: 2)
        }
        .frame(width: width, height: height)
    }
}

struct BottomNavigationView: View {
    @Binding var selectedTab: Int
    @Binding var showMessaging: Bool
    @Binding var showHamburgerMenu: Bool
    @Binding var path: NavigationPath
    
    var body: some View {
        HStack(spacing: 0) {
            // Profile Tab
            Button(action: {
                selectedTab = 0
                path.append("profile")
            }) {
                VStack(spacing: 6) {
                    Image(systemName: selectedTab == 0 ? "person.circle.fill" : "person.circle")
                        .font(.system(size: 40, weight: .medium))
                    Text("Profile")
                        .font(DesignSystem.Typography.bodySmall)
                        .fontWeight(.medium)
                }
                .foregroundColor(selectedTab == 0 ? DesignSystem.Colors.secondary : DesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity)
            }
            
            // Messaging Tab
            Button(action: {
                selectedTab = 1
                path.append("messaging")
            }) {
                VStack(spacing: 6) {
                    Image(systemName: selectedTab == 1 ? "message.circle.fill" : "message.circle")
                        .font(.system(size: 40, weight: .medium))
                    Text("Messages")
                        .font(DesignSystem.Typography.bodySmall)
                        .fontWeight(.medium)
                }
                .foregroundColor(selectedTab == 1 ? DesignSystem.Colors.secondary : DesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity)
            }
            
            // Menu Tab
            Button(action: {
                selectedTab = 2
                showHamburgerMenu = true
            }) {
                VStack(spacing: 6) {
                    Image(systemName: selectedTab == 2 ? "line.3.horizontal.circle.fill" : "line.3.horizontal")
                        .font(.system(size: 40, weight: .medium))
                }
                .foregroundColor(selectedTab == 2 ? DesignSystem.Colors.secondary : DesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .padding(.bottom, -60) // Negative padding to push beyond safe area
        .background(DesignSystem.Colors.surface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(DesignSystem.Colors.secondary.opacity(0.3)),
            alignment: .top
        )
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

struct HamburgerMenuView: View {
    @Binding var showHamburgerMenu: Bool
    @Binding var path: NavigationPath
    @Binding var showLogoutAlert: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Close") {
                        showHamburgerMenu = false
                    }
                    .foregroundColor(DesignSystem.Colors.secondary)
                    
                    Spacer()
                    
                    Text("Menu")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Spacer()
                    
                    Button("Logout") {
                        showLogoutAlert = true
                        showHamburgerMenu = false
                    }
                    .foregroundColor(DesignSystem.Colors.secondary)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.surface)
                
                // Menu Items
                ScrollView {
                    VStack(spacing: 0) {
                        MenuButton(title: "Messages", icon: "message.circle") {
                            path.append("messaging")
                            showHamburgerMenu = false
                        }
                        
                        MenuButton(title: "Transaction History", icon: "clock.arrow.circlepath") {
                            path.append("transactions")
                            showHamburgerMenu = false
                        }
                        
                        MenuButton(title: "Send/Receive TLS", icon: "arrow.left.arrow.right") {
                            path.append("send")
                            showHamburgerMenu = false
                        }
                        
                        MenuButton(title: "Network Stats", icon: "chart.bar") {
                            path.append("stats")
                            showHamburgerMenu = false
                        }
                        
                        MenuButton(title: "AI Features", icon: "brain.head.profile") {
                            path.append("ai")
                            showHamburgerMenu = false
                        }
                        
                        MenuButton(title: "Settings", icon: "gearshape") {
                            path.append("settings")
                            showHamburgerMenu = false
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.md)
                }
            }
        }
    }
}



struct MenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(DesignSystem.Colors.secondary)
                    .frame(width: 24)
                
                Text(title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.text)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
}



// MARK: - Profile View
struct ProfileView: View {
    @Binding var path: NavigationPath
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isStreaming = false
    @State private var voiceEnabled = false // Disabled by default
    @State private var autoRespond = false
    @State private var profileImage: UIImage?
    @State private var showImagePicker = false
    @State private var displayName = "PAAI User"
    @State private var userBio = ""
    @State private var userLocation = ""
    @State private var biometricEnabled = true
    @State private var showSessionManagement = false
    @State private var showAnalytics = false
    @State private var showBugReport = false
    @State private var selectedLanguage = "English"
    @State private var selectedCurrency = "USD"
    @State private var selectedTheme = "Auto"
    @State private var availableLanguages = ["English", "Spanish", "French", "German", "Chinese"]
    @State private var availableCurrencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD"]
    @State private var availableThemes = ["Auto", "Light", "Dark"]
    @State private var bugDescription = ""
    @State private var bugCategory = "General"
    @State private var bugCategories = ["General", "AI Issues", "Payment Issues", "UI/UX", "Performance", "Security"]
    @State private var analyticsData: AnalyticsData?
    @State private var activeSessions: [SessionInfo] = []
    private let walletService = WalletService.shared

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Header with Back Button
                HStack {
                    Button(action: {
                        path.removeLast()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(DesignSystem.Colors.text)
                            .font(.system(size: 20))
                            .padding(DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.surface)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Profile & Settings")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Spacer()
                    
                    // Placeholder for symmetry
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.lg)
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Profile Picture Section
                        CardView {
                            VStack(spacing: DesignSystem.Spacing.md) {
                                Text("Personal Information")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.text)
                                
                                // Profile Picture
                                Button(action: {
                                    showImagePicker = true
                                }) {
                                    if let profileImage = profileImage {
                                        Image(uiImage: profileImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(DesignSystem.Colors.secondary, lineWidth: 3)
                                            )
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 100))
                                            .foregroundColor(DesignSystem.Colors.secondary)
                                    }
                                }
                                
                                Text("Tap to upload photo")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                // Personal Info Fields
                                VStack(spacing: DesignSystem.Spacing.sm) {
                                    InputField("Display Name", text: $displayName)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    InputField("Bio", text: $userBio)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    InputField("Location", text: $userLocation)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        // Wallet Info
                        CardView {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                Text("Wallet Information")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.text)
                                
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                    Button(action: {
                                        if let address = walletService.loadAddress() {
                                            UIPasteboard.general.string = address
                                            alertMessage = "Address copied to clipboard!"
                                            showAlert = true
                                        }
                                    }) {
                                        VStack(spacing: DesignSystem.Spacing.xs) {
                                            Text("TLS Address")
                                                .font(DesignSystem.Typography.caption)
                                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                            
                                            Text(formatAddress(walletService.loadAddress() ?? "Not set"))
                                                .font(DesignSystem.Typography.bodyMedium)
                                                .foregroundColor(DesignSystem.Colors.text)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                            
                                            Text("Tap to copy")
                                                .font(DesignSystem.Typography.caption)
                                                .foregroundColor(DesignSystem.Colors.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(DesignSystem.Spacing.sm)
                                        .background(DesignSystem.Colors.surface.opacity(0.5))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    
                                    Text("Subscription: \(walletService.checkSubscription() ? "Active" : "Inactive")")
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .foregroundColor(walletService.checkSubscription() ? DesignSystem.Colors.success : DesignSystem.Colors.error)
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        // AI Status
                        CardView {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                Text("AI Status")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.text)
                                
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    HStack {
                                        Image(systemName: "brain.head.profile")
                                            .foregroundColor(DesignSystem.Colors.secondary)
                                            .font(.system(size: 20))
                                        
                                        Text("xAI Grok Integration")
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .foregroundColor(DesignSystem.Colors.text)
                                        
                                        Spacer()
                                        
                                        Text("Active")
                                            .font(DesignSystem.Typography.bodySmall)
                                            .foregroundColor(DesignSystem.Colors.success)
                                            .padding(.horizontal, DesignSystem.Spacing.sm)
                                            .padding(.vertical, 4)
                                            .background(DesignSystem.Colors.success.opacity(0.2))
                                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                                    }
                                    
                                    Text("AI features are automatically configured")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        // Security & Session Management
                        CardView {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                Text("Security & Sessions")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.text)
                                
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    Toggle("Biometric Authentication", isOn: $biometricEnabled)
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .foregroundColor(DesignSystem.Colors.text)
                                    
                                    Button(action: {
                                        showSessionManagement = true
                                    }) {
                                        HStack {
                                            Image(systemName: "iphone")
                                                .foregroundColor(DesignSystem.Colors.secondary)
                                            Text("Manage Sessions")
                                                .font(DesignSystem.Typography.bodyMedium)
                                                .foregroundColor(DesignSystem.Colors.text)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        // Preferences
                        CardView {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                Text("Preferences")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.text)
                                
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    HStack {
                                        Text("Language")
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .foregroundColor(DesignSystem.Colors.text)
                                        Spacer()
                                        Picker("Language", selection: $selectedLanguage) {
                                            ForEach(availableLanguages, id: \.self) { language in
                                                Text(language).tag(language)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                    }
                                    
                                    HStack {
                                        Text("Currency")
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .foregroundColor(DesignSystem.Colors.text)
                                        Spacer()
                                        Picker("Currency", selection: $selectedCurrency) {
                                            ForEach(availableCurrencies, id: \.self) { currency in
                                                Text(currency).tag(currency)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                    }
                                    
                                    HStack {
                                        Text("Theme")
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .foregroundColor(DesignSystem.Colors.text)
                                        Spacer()
                                        Picker("Theme", selection: $selectedTheme) {
                                            ForEach(availableThemes, id: \.self) { theme in
                                                Text(theme).tag(theme)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        // Analytics
                        CardView {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                Text("Analytics")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.text)
                                
                                Button(action: {
                                    showAnalytics = true
                                }) {
                                    HStack {
                                        Image(systemName: "chart.bar.fill")
                                            .foregroundColor(DesignSystem.Colors.secondary)
                                        Text("View Usage Analytics")
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .foregroundColor(DesignSystem.Colors.text)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                    }
                                    .padding(.vertical, DesignSystem.Spacing.sm)
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        // Support & Help
                        CardView {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                Text("Support & Help")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.text)
                                
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    Button(action: {
                                        showBugReport = true
                                    }) {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(DesignSystem.Colors.error)
                                            Text("Report a Bug")
                                                .font(DesignSystem.Typography.bodyMedium)
                                                .foregroundColor(DesignSystem.Colors.text)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                        }
                                        .padding(.vertical, DesignSystem.Spacing.sm)
                                    }
                                    
                                    Button(action: {
                                        if let url = URL(string: "https://discord.gg/VmFXfHnZE5") {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "message.circle.fill")
                                                .foregroundColor(DesignSystem.Colors.secondary)
                                            Text("Speak with Team")
                                                .font(DesignSystem.Typography.bodyMedium)
                                                .foregroundColor(DesignSystem.Colors.text)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                        }
                                        .padding(.vertical, DesignSystem.Spacing.sm)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        // Action Buttons
                        VStack(spacing: DesignSystem.Spacing.md) {
                            PrimaryButton("Test Connection") {
                                testConnection()
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        Spacer(minLength: DesignSystem.Spacing.xl)
                    }
                    .padding(.vertical, DesignSystem.Spacing.lg)
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Success", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $profileImage)
        }
        .sheet(isPresented: $showSessionManagement) {
            SessionManagementView(sessions: $activeSessions)
        }
        .sheet(isPresented: $showAnalytics) {
            AnalyticsView(analyticsData: $analyticsData)
        }
        .sheet(isPresented: $showBugReport) {
            BugReportView(bugDescription: $bugDescription, bugCategory: $bugCategory, bugCategories: bugCategories)
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private func formatAddress(_ address: String) -> String {
        if address.count > 20 {
            let start = String(address.prefix(10))
            let end = String(address.suffix(10))
            return "\(start)...\(end)"
        }
        return address
    }
    
    private func testConnection() {
        alertMessage = "Connection test completed successfully!"
        showAlert = true
    }
    
    private func loadSettings() {
        // Load saved settings here
    }
}

struct MessagesView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Text("Messages")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Text("Messages view coming soon...")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.xl)
            }
            .navigationBarHidden(true)
        }
    }
}

struct TransactionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Text("Transaction History")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Text("Transaction history coming soon...")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.xl)
            }
            .navigationBarHidden(true)
        }
    }
}

struct SendView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Text("Send TLS")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Text("Send functionality coming soon...")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.xl)
            }
            .navigationBarHidden(true)
        }
    }
}

struct ReceiveView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Text("Receive TLS")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Text("Receive functionality coming soon...")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.xl)
            }
            .navigationBarHidden(true)
        }
    }
}

struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Text("Network Stats")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Text("Network statistics coming soon...")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.xl)
            }
            .navigationBarHidden(true)
        }
    }
}

struct AIFeaturesView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Text("AI Features")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Text("AI features coming soon...")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.xl)
            }
            .navigationBarHidden(true)
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Text("Settings")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Text("Settings coming soon...")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.xl)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Supporting Views for Profile
struct SessionManagementView: View {
    @Binding var sessions: [SessionInfo]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.lg) {
                    HStack {
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundColor(DesignSystem.Colors.secondary)
                        
                        Spacer()
                        
                        Text("Active Sessions")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.text)
                        
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.lg)
                    
                    if sessions.isEmpty {
                        VStack(spacing: DesignSystem.Spacing.md) {
                            CardView {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                    HStack {
                                        Image(systemName: "iphone")
                                            .foregroundColor(DesignSystem.Colors.secondary)
                                        Text("iPhone 16 Pro")
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .foregroundColor(DesignSystem.Colors.text)
                                        Spacer()
                                        Text("Current")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.success)
                                            .padding(.horizontal, DesignSystem.Spacing.sm)
                                            .padding(.vertical, 2)
                                            .background(DesignSystem.Colors.success.opacity(0.2))
                                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                                    }
                                    
                                    Text("Last active: Just now")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            
                            CardView {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                    HStack {
                                        Image(systemName: "macbook")
                                            .foregroundColor(DesignSystem.Colors.secondary)
                                        Text("MacBook Pro")
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .foregroundColor(DesignSystem.Colors.text)
                                        Spacer()
                                        Text("2 hours ago")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                    }
                                    
                                    Text("Last active: 2 hours ago")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: DesignSystem.Spacing.md) {
                                ForEach(sessions) { session in
                                    CardView {
                                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                            HStack {
                                                Image(systemName: "iphone")
                                                    .foregroundColor(DesignSystem.Colors.secondary)
                                                Text(session.deviceName)
                                                    .font(DesignSystem.Typography.bodyMedium)
                                                    .foregroundColor(DesignSystem.Colors.text)
                                                Spacer()
                                                if session.isCurrent {
                                                    Text("Current")
                                                        .font(DesignSystem.Typography.caption)
                                                        .foregroundColor(DesignSystem.Colors.success)
                                                        .padding(.horizontal, DesignSystem.Spacing.sm)
                                                        .padding(.vertical, 2)
                                                        .background(DesignSystem.Colors.success.opacity(0.2))
                                                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                                                } else {
                                                    Text(session.lastActive, style: .relative)
                                                        .font(DesignSystem.Typography.caption)
                                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                                }
                                            }
                                            
                                            Text("Location: \(session.location)")
                                                .font(DesignSystem.Typography.caption)
                                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                        }
                                    }
                                    .padding(.horizontal, DesignSystem.Spacing.lg)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct AnalyticsView: View {
    @Binding var analyticsData: AnalyticsData?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.lg) {
                    HStack {
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundColor(DesignSystem.Colors.secondary)
                        
                        Spacer()
                        
                        Text("Usage Analytics")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.text)
                        
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.lg)
                    
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            if let data = analyticsData {
                                // Transaction Stats
                                CardView {
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                        Text("Transaction Statistics")
                                            .font(DesignSystem.Typography.headline)
                                            .foregroundColor(DesignSystem.Colors.text)
                                        
                                        VStack(spacing: DesignSystem.Spacing.sm) {
                                            HStack {
                                                Text("Total Transactions")
                                                    .font(DesignSystem.Typography.bodyMedium)
                                                    .foregroundColor(DesignSystem.Colors.text)
                                                Spacer()
                                                Text("\(data.totalTransactions)")
                                                    .font(DesignSystem.Typography.bodyMedium)
                                                    .foregroundColor(DesignSystem.Colors.secondary)
                                            }
                                            
                                            HStack {
                                                Text("Total Volume")
                                                    .font(DesignSystem.Typography.bodyMedium)
                                                    .foregroundColor(DesignSystem.Colors.text)
                                                Spacer()
                                                Text("\(String(format: "%.2f", data.totalVolume)) TLS")
                                                    .font(DesignSystem.Typography.bodyMedium)
                                                    .foregroundColor(DesignSystem.Colors.secondary)
                                            }
                                            
                                            HStack {
                                                Text("Average Transaction")
                                                    .font(DesignSystem.Typography.bodyMedium)
                                                    .foregroundColor(DesignSystem.Colors.text)
                                                Spacer()
                                                Text("\(String(format: "%.2f", data.averageTransactionSize)) TLS")
                                                    .font(DesignSystem.Typography.bodyMedium)
                                                    .foregroundColor(DesignSystem.Colors.secondary)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                                
                                // Usage Stats
                                CardView {
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                        Text("Usage Statistics")
                                            .font(DesignSystem.Typography.headline)
                                            .foregroundColor(DesignSystem.Colors.text)
                                        
                                        VStack(spacing: DesignSystem.Spacing.sm) {
                                            HStack {
                                                Text("Daily Active Minutes")
                                                    .font(DesignSystem.Typography.bodyMedium)
                                                    .foregroundColor(DesignSystem.Colors.text)
                                                Spacer()
                                                Text("\(data.dailyActiveMinutes)")
                                                    .font(DesignSystem.Typography.bodyMedium)
                                                    .foregroundColor(DesignSystem.Colors.secondary)
                                            }
                                            
                                            HStack {
                                                Text("Most Used Feature")
                                                    .font(DesignSystem.Typography.bodyMedium)
                                                    .foregroundColor(DesignSystem.Colors.text)
                                                Spacer()
                                                Text(data.mostUsedFeatures.first?.key ?? "N/A")
                                                    .font(DesignSystem.Typography.bodyMedium)
                                                    .foregroundColor(DesignSystem.Colors.secondary)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                            } else {
                                CardView {
                                    VStack(spacing: DesignSystem.Spacing.md) {
                                        Image(systemName: "chart.bar.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(DesignSystem.Colors.secondary)
                                        
                                        Text("No Analytics Data")
                                            .font(DesignSystem.Typography.headline)
                                            .foregroundColor(DesignSystem.Colors.text)
                                        
                                        Text("Analytics data will appear here as you use the app")
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                            }
                        }
                        .padding(.vertical, DesignSystem.Spacing.lg)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct BugReportView: View {
    @Binding var bugDescription: String
    @Binding var bugCategory: String
    let bugCategories: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var showSuccessAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.lg) {
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(DesignSystem.Colors.secondary)
                        
                        Spacer()
                        
                        Text("Report Bug")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.text)
                        
                        Spacer()
                        
                        Button("Submit") {
                            submitBugReport()
                        }
                        .foregroundColor(DesignSystem.Colors.secondary)
                        .disabled(bugDescription.isEmpty)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.lg)
                    
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            // Category Selection
                            CardView {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                    Text("Bug Category")
                                        .font(DesignSystem.Typography.headline)
                                        .foregroundColor(DesignSystem.Colors.text)
                                    
                                    Picker("Category", selection: $bugCategory) {
                                        ForEach(bugCategories, id: \.self) { category in
                                            Text(category).tag(category)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            
                            // Bug Description
                            CardView {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                    Text("Bug Description")
                                        .font(DesignSystem.Typography.headline)
                                        .foregroundColor(DesignSystem.Colors.text)
                                    
                                    TextField("Describe the issue in detail...", text: $bugDescription, axis: .vertical)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .lineLimit(5...10)
                                        .font(DesignSystem.Typography.bodyMedium)
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            
                            // Additional Info
                            CardView {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                    Text("Additional Information")
                                        .font(DesignSystem.Typography.headline)
                                        .foregroundColor(DesignSystem.Colors.text)
                                    
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                        Text("• Please include steps to reproduce the issue")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                        
                                        Text("• Describe what you expected to happen")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                        
                                        Text("• Include any error messages you saw")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                    }
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        }
                        .padding(.vertical, DesignSystem.Spacing.lg)
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("Bug Report Submitted", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for your feedback. We'll review your report and get back to you soon.")
            }
        }
    }
    
    private func submitBugReport() {
        // Here you would typically send the bug report to your backend
        // For now, we'll just show a success message
        showSuccessAlert = true
    }
}

struct EditPersonalInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.lg) {
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(DesignSystem.Colors.secondary)
                        
                        Spacer()
                        
                        Text("Edit Profile")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.text)
                        
                        Spacer()
                        
                        Button("Save") {
                            dismiss()
                        }
                        .foregroundColor(DesignSystem.Colors.secondary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.lg)
                    
                    VStack(spacing: DesignSystem.Spacing.md) {
                        InputField("Display Name", text: .constant(""))
                        InputField("Bio", text: .constant(""))
                        InputField("Location", text: .constant(""))
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Additional Views
struct PrioritizationView: View {
    let messages: [Message]
    @Binding var path: NavigationPath
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                HStack {
                    Button("Back") {
                        path.removeLast()
                    }
                    .foregroundColor(DesignSystem.Colors.secondary)
                    
                    Spacer()
                    
                    Text("Message Prioritization")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.lg)
                
                Text("Message prioritization coming soon...")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                
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
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                HStack {
                    Button("Back") {
                        path.removeLast()
                    }
                    .foregroundColor(DesignSystem.Colors.secondary)
                    
                    Spacer()
                    
                    Text("User Portal")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.lg)
                
                Text("User portal coming soon...")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
}

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.xl) {
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
                            // Process subscription
                            dismiss()
                        }
                        
                        Text("10 TLS / month")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(DesignSystem.Spacing.xl)
            }
            .navigationBarHidden(true)
        }
    }
}

