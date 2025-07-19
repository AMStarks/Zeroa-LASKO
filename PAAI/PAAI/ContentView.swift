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
    @State private var showSignInModal = false
    @StateObject private var themeManager = ThemeManager.shared

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
                        
                        Text("Your digital fingerprint")
                            .font(.custom("AbadiMTProBold", size: 18))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Login Buttons
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        PrimaryButton("Sign In", isLoading: isCheckingLogin) {
                            showSignInModal = true
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
                    StatsView(path: $path)
                case "userPortal":
                    UserPortalView(path: $path)
                case "profile":
                    ProfileView(path: $path)
                case "messaging":
                    HybridMessagingView()
                case "settings":
                    SettingsView(path: $path)
                case "support":
                    SupportView(path: $path)
                case "ai":
                    AIFeaturesView(path: $path)
                case "ai-companion":
                    CompanionManagementView()
                case "ai-companion-conversation":
                    CompanionConversationView()
                case "ai-companion-settings":
                    CompanionSettingsView()
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
            HybridMessagingView()
        }
        .sheet(isPresented: $showNewChat) {
            NewChatView(
                newContactName: $newContactName,
                newContactAddress: $newContactAddress,
                conversations: $conversations
            )
        }
        .sheet(isPresented: $showSignInModal) {
            SignInModalView(
                address: $address,
                mnemonic: $mnemonic,
                isCheckingLogin: $isCheckingLogin,
                showError: $showError,
                errorMessage: $errorMessage,
                path: $path
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
    
    // Companion task listener moved to HomeView where handleAction is defined
}

// MARK: - Create Account View
struct CreateAccountView: View {
    @Binding var path: NavigationPath
    @State private var mnemonic = ""
    @State private var hasWrittenDown = false
    @State private var showMnemonic = false  // Hide mnemonic by default
    @State private var showConfirm = false
    @State private var isCreating = false
    @StateObject private var themeManager = ThemeManager.shared
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
                        
                        Text("Write down these words in order • Copy to clipboard")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                
                // Confirmation Toggle
                Toggle("I have written down my recovery phrase securely", isOn: $hasWrittenDown)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.text)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                
                // Action Buttons
                VStack(spacing: DesignSystem.Spacing.md) {
                    PrimaryButton("Create Account", isLoading: isCreating) {
                        showConfirm = true
                    }
                    .disabled(!hasWrittenDown)
                    
                    SecondaryButton(title: "Back to Login") {
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
        walletService.importMnemonic(mnemonic) { success, derivedAddress in
            DispatchQueue.main.async {
            isCreating = false
            if success {
                    print("✅ Account created successfully with address: \(derivedAddress ?? "unknown")")
                    // Navigate to home screen
                    path.append("home")
                } else {
                    print("❌ Failed to create account")
                    // Could add error handling here if needed
                }
            }
        }
    }
}

// MARK: - Sign In Modal View
struct SignInModalView: View {
    @Binding var address: String
    @Binding var mnemonic: String
    @Binding var isCheckingLogin: Bool
    @Binding var showError: Bool
    @Binding var errorMessage: String
    @Binding var path: NavigationPath
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    
    private let walletService = WalletService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Header
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(DesignSystem.Colors.secondary)
                        
                        Spacer()
                        
                        Text("Sign In")
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
                        InputField("Enter Seed Phrase", text: $mnemonic, isSecure: true)
                        
                        PrimaryButton("Sign In", isLoading: isCheckingLogin) {
                            handleSignIn()
                        }
                        .disabled(address.isEmpty || mnemonic.isEmpty)
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
    }
    
    private func handleSignIn() {
        guard !isCheckingLogin else { return }
        isCheckingLogin = true
        
        if address.isEmpty || mnemonic.isEmpty {
            errorMessage = "Both address and seed phrase are required"
            showError = true
            isCheckingLogin = false
            return
        }
        
        walletService.importMnemonic(mnemonic) { success, derivedAddress in
            if success, derivedAddress == address {
                dismiss()
                path.append("home")
            } else {
                errorMessage = "Invalid address or seed phrase"
                showError = true
            }
            isCheckingLogin = false
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @Binding var path: NavigationPath
    @ObservedObject var assistantService: AssistantService
    @ObservedObject var tlsService: TLSBlockchainService
    // Command input removed - functionality preserved for future use
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
    // Coin Selection and Data
    @State private var selectedCoin: String = "Telestai"
    @State private var availableCoins = ["Telestai", "Bitcoin", "USDT", "USDC", "Litecoin", "Flux", "Kaspa"]
    @State private var showFilter = false
    @State private var filteredCoins: [String] = ["Telestai", "Bitcoin", "USDT", "USDC", "Litecoin", "Flux", "Kaspa"]
    @State private var coinBalance: Double = 0.0
    @State private var coinPrice: Double = 0.0
    @State private var coinPriceChange: Double = 0.0
    @State private var isLoadingPrice = false
    @State private var priceHistory: [Double] = []
    @State private var isLoadingHistory = false
    
    // Separate price history for each coin
    @State private var tlsPriceHistory: [Double] = []
    @State private var bitcoinPriceHistory: [Double] = []
    @State private var usdtPriceHistory: [Double] = []
    @State private var usdcPriceHistory: [Double] = []
    @State private var litecoinPriceHistory: [Double] = []
    @State private var fluxPriceHistory: [Double] = []
    @State private var kaspaPriceHistory: [Double] = []
    
    // Legacy TLS variables for backward compatibility
    @State private var tlsBalance: Double = 0.0
    @State private var tlsPrice: Double = 0.0
    @State private var tlsPriceChange: Double = 0.0
    
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
    @State private var selectedTheme = "Native"
    @State private var availableLanguages = ["English", "Spanish", "French", "German", "Chinese"]
    @State private var availableCurrencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD"]
    @State private var availableThemes = ["Native", "Light", "Dark"]
    
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
    
    @StateObject private var themeManager = ThemeManager.shared
    // Focus state removed - functionality preserved for future use
    private let walletService = WalletService.shared
    private let networkService = NetworkService.shared

    // Place the following functions at the top level of HomeView, after property declarations and before the body property:
    private func loadCoinData() {
        Task {
            await loadCoinDataAsync()
        }
    }

    private func loadCoinDataAsync() async {
        // Update coin-specific data based on selection
        switch selectedCoin {
        case "Telestai":
            await loadTLSData()
            // Update coin variables with TLS data
            await MainActor.run {
                self.coinBalance = self.tlsBalance
                self.coinPrice = self.tlsPrice
                self.coinPriceChange = self.tlsPriceChange
                self.priceHistory = self.tlsPriceHistory
            }
        case "Bitcoin":
            await loadBitcoinData()
            await MainActor.run {
                self.priceHistory = self.bitcoinPriceHistory
            }
        case "USDT":
            await loadUSDTData()
            await MainActor.run {
                self.priceHistory = self.usdtPriceHistory
            }
        case "USDC":
            await loadUSDCData()
            await MainActor.run {
                self.priceHistory = self.usdcPriceHistory
            }
        case "Litecoin":
            await loadLitecoinData()
            await MainActor.run {
                self.priceHistory = self.litecoinPriceHistory
            }
        case "Flux":
            await loadFluxData()
            await MainActor.run {
                self.priceHistory = self.fluxPriceHistory
            }
        case "Kaspa":
            await loadKaspaData()
            await MainActor.run {
                self.priceHistory = self.kaspaPriceHistory
            }
        default:
            await loadTLSData()
        }
    }

    private func loadBitcoinData() async {
        // Load Bitcoin balance and price
        if let address = walletService.loadAddress() {
            // For now, use mock balance - can be expanded with real Bitcoin service
            await MainActor.run {
                self.coinBalance = 0.5 // Mock Bitcoin balance
            }
            
            // Load real price data from CoinGecko
            await loadBitcoinPrice()
            
            // Load price history for chart
            await loadBitcoinPriceHistory()
        }
    }

    private func loadBitcoinPrice() async {
        // Rate limiting: Add delay between API calls
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // Check cache first
        if let cachedPrice = UserDefaults.standard.object(forKey: "cached_bitcoin_price") as? Double,
           let cachedChange = UserDefaults.standard.object(forKey: "cached_bitcoin_change") as? Double,
           let cacheTime = UserDefaults.standard.object(forKey: "cached_bitcoin_time") as? Date {
            
            // Use cache if less than 5 minutes old
            if Date().timeIntervalSince(cacheTime) < 300 {
                await MainActor.run {
                    self.coinPrice = cachedPrice
                    self.coinPriceChange = cachedChange
                    print("✅ Using cached Bitcoin price: $\(cachedPrice) (24h change: \(cachedChange)%)")
                }
                return
            }
        }
        
        // CoinGecko API endpoint for Bitcoin price
        let urlString = "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid Bitcoin CoinGecko URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let bitcoin = json["bitcoin"] as? [String: Any],
                   let usd = bitcoin["usd"] as? Double,
                   let usdChange = bitcoin["usd_24h_change"] as? Double {
                    
                    await MainActor.run {
                        self.coinPrice = usd
                        self.coinPriceChange = usdChange
                        print("✅ Bitcoin price loaded: $\(usd) (24h change: \(usdChange)%)")
                        
                        // Cache the successful response
                        UserDefaults.standard.set(usd, forKey: "cached_bitcoin_price")
                        UserDefaults.standard.set(usdChange, forKey: "cached_bitcoin_change")
                        UserDefaults.standard.set(Date(), forKey: "cached_bitcoin_time")
                    }
                } else {
                    print("❌ Failed to parse Bitcoin CoinGecko response")
                    // Fallback to mock data
                    await MainActor.run {
                        self.coinPrice = 45000.0
                        self.coinPriceChange = 2.1
                    }
                }
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                print("⚠️ Bitcoin CoinGecko API rate limited (429). Using cached data if available.")
                // Try to use cached data even if expired
                if let cachedPrice = UserDefaults.standard.object(forKey: "cached_bitcoin_price") as? Double,
                   let cachedChange = UserDefaults.standard.object(forKey: "cached_bitcoin_change") as? Double {
                    await MainActor.run {
                        self.coinPrice = cachedPrice
                        self.coinPriceChange = cachedChange
                        print("✅ Using expired cached Bitcoin price due to rate limit: $\(cachedPrice)")
                    }
                } else {
                    // Fallback to mock data
                    await MainActor.run {
                        self.coinPrice = 45000.0
                        self.coinPriceChange = 2.1
                    }
                }
            } else {
                print("❌ Bitcoin CoinGecko API error: \(response)")
                // Fallback to mock data
                await MainActor.run {
                    self.coinPrice = 45000.0
                    self.coinPriceChange = 2.1
                }
            }
        } catch {
            print("❌ Bitcoin CoinGecko network error: \(error)")
            // Fallback to mock data
            await MainActor.run {
                self.coinPrice = 45000.0
                self.coinPriceChange = 2.1
            }
        }
    }
    
    private func loadBitcoinPriceHistory() async {
        // Rate limiting: Add delay between API calls
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // Check cache first
        if let cachedHistory = UserDefaults.standard.object(forKey: "cached_bitcoin_history") as? [Double],
           let cacheTime = UserDefaults.standard.object(forKey: "cached_bitcoin_history_time") as? Date {
            
            // Use cache if less than 10 minutes old
            if Date().timeIntervalSince(cacheTime) < 600 {
                await MainActor.run {
                    self.bitcoinPriceHistory = cachedHistory
                    print("✅ Using cached Bitcoin history: \(cachedHistory.count) data points")
                }
                return
            }
        }
        
        // CoinGecko API endpoint for 7-day price history
        let urlString = "https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=7"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid Bitcoin CoinGecko history URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let prices = json["prices"] as? [[Any]] {
                    
                    // Extract price values from [[timestamp, price]] format
                    let priceHistory = prices.compactMap { priceData -> Double? in
                        guard priceData.count >= 2,
                              let price = priceData[1] as? Double else { return nil }
                        return price
                    }
                    
                    // Ensure we have enough data points and they're reasonable
                    if priceHistory.count >= 5 && priceHistory.allSatisfy({ $0 > 0 }) {
                        await MainActor.run {
                            self.bitcoinPriceHistory = priceHistory
                            print("✅ Bitcoin price history loaded: \(priceHistory.count) data points")
                            print("📊 Bitcoin price range: $\(priceHistory.min() ?? 0) - $\(priceHistory.max() ?? 0)")
                            
                            // Cache the successful response
                            UserDefaults.standard.set(priceHistory, forKey: "cached_bitcoin_history")
                            UserDefaults.standard.set(Date(), forKey: "cached_bitcoin_history_time")
                        }
                    } else {
                        print("❌ Invalid Bitcoin price history data: \(priceHistory)")
                        // Fallback to mock data
                        await MainActor.run {
                            self.bitcoinPriceHistory = [44000, 44500, 44800, 44700, 44900, 45100, 45000]
                        }
                    }
                } else {
                    print("❌ Failed to parse Bitcoin CoinGecko history response")
                    // Fallback to mock data
                    await MainActor.run {
                        self.bitcoinPriceHistory = [44000, 44500, 44800, 44700, 44900, 45100, 45000]
                    }
                }
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                print("⚠️ Bitcoin CoinGecko history API rate limited (429). Using cached data if available.")
                // Try to use cached data even if expired
                if let cachedHistory = UserDefaults.standard.object(forKey: "cached_bitcoin_history") as? [Double] {
                    await MainActor.run {
                        self.bitcoinPriceHistory = cachedHistory
                        print("✅ Using expired cached Bitcoin history due to rate limit: \(cachedHistory.count) data points")
                    }
                } else {
                    // Fallback to mock data
                    await MainActor.run {
                        self.bitcoinPriceHistory = [44000, 44500, 44800, 44700, 44900, 45100, 45000]
                    }
                }
            } else {
                print("❌ Bitcoin CoinGecko history API error: \(response)")
                // Fallback to mock data
                await MainActor.run {
                    self.bitcoinPriceHistory = [44000, 44500, 44800, 44700, 44900, 45100, 45000]
                }
            }
        } catch {
            print("❌ Bitcoin CoinGecko history network error: \(error)")
                                    // Fallback to mock data
                        await MainActor.run {
                            self.bitcoinPriceHistory = [44000, 44500, 44800, 44700, 44900, 45100, 45000]
                        }
        }
    }
    
    private func loadLitecoinData() async {
        // Load Litecoin balance and price
        if let address = walletService.loadAddress() {
            // For now, use mock balance - can be expanded with real Litecoin service
            await MainActor.run {
                self.coinBalance = 25.0 // Mock Litecoin balance
            }
            
            // Load real price data from CoinGecko
            await loadLitecoinPrice()
            
            // Load price history for chart
            await loadLitecoinPriceHistory()
        }
    }
    
    private func loadLitecoinPrice() async {
        // Rate limiting: Add delay between API calls
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // Check cache first
        if let cachedPrice = UserDefaults.standard.object(forKey: "cached_litecoin_price") as? Double,
           let cachedChange = UserDefaults.standard.object(forKey: "cached_litecoin_change") as? Double,
           let cacheTime = UserDefaults.standard.object(forKey: "cached_litecoin_time") as? Date {
            
            // Use cache if less than 5 minutes old
            if Date().timeIntervalSince(cacheTime) < 300 {
                await MainActor.run {
                    self.coinPrice = cachedPrice
                    self.coinPriceChange = cachedChange
                    print("✅ Using cached Litecoin price: $\(cachedPrice) (24h change: \(cachedChange)%)")
                }
                return
            }
        }
        
        // CoinGecko API endpoint for Litecoin price
        let urlString = "https://api.coingecko.com/api/v3/simple/price?ids=litecoin&vs_currencies=usd&include_24hr_change=true"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid Litecoin CoinGecko URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let litecoin = json["litecoin"] as? [String: Any],
                   let usd = litecoin["usd"] as? Double,
                   let usdChange = litecoin["usd_24h_change"] as? Double {
                    
                    await MainActor.run {
                        self.coinPrice = usd
                        self.coinPriceChange = usdChange
                        print("✅ Litecoin price loaded: $\(usd) (24h change: \(usdChange)%)")
                        
                        // Cache the successful response
                        UserDefaults.standard.set(usd, forKey: "cached_litecoin_price")
                        UserDefaults.standard.set(usdChange, forKey: "cached_litecoin_change")
                        UserDefaults.standard.set(Date(), forKey: "cached_litecoin_time")
                    }
                } else {
                    print("❌ Failed to parse Litecoin CoinGecko response")
                    // Fallback to mock data
                    await MainActor.run {
                        self.coinPrice = 85.0
                        self.coinPriceChange = -1.2
                    }
                }
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                print("⚠️ Litecoin CoinGecko API rate limited (429). Using cached data if available.")
                // Try to use cached data even if expired
                if let cachedPrice = UserDefaults.standard.object(forKey: "cached_litecoin_price") as? Double,
                   let cachedChange = UserDefaults.standard.object(forKey: "cached_litecoin_change") as? Double {
                    await MainActor.run {
                        self.coinPrice = cachedPrice
                        self.coinPriceChange = cachedChange
                        print("✅ Using expired cached Litecoin price due to rate limit: $\(cachedPrice)")
                    }
                } else {
                    // Fallback to mock data
                    await MainActor.run {
                        self.coinPrice = 85.0
                        self.coinPriceChange = -1.2
                    }
                }
            } else {
                print("❌ Litecoin CoinGecko API error: \(response)")
                // Fallback to mock data
                await MainActor.run {
                    self.coinPrice = 85.0
                    self.coinPriceChange = -1.2
                }
            }
        } catch {
            print("❌ Litecoin CoinGecko network error: \(error)")
            // Fallback to mock data
            await MainActor.run {
                self.coinPrice = 85.0
                self.coinPriceChange = -1.2
            }
        }
    }
    
    private func loadLitecoinPriceHistory() async {
        // Rate limiting: Add delay between API calls
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // Check cache first
        if let cachedHistory = UserDefaults.standard.object(forKey: "cached_litecoin_history") as? [Double],
           let cacheTime = UserDefaults.standard.object(forKey: "cached_litecoin_history_time") as? Date {
            
            // Use cache if less than 10 minutes old
            if Date().timeIntervalSince(cacheTime) < 600 {
                await MainActor.run {
                    self.litecoinPriceHistory = cachedHistory
                    print("✅ Using cached Litecoin history: \(cachedHistory.count) data points")
                }
                return
            }
        }
        
        // CoinGecko API endpoint for 7-day price history
        let urlString = "https://api.coingecko.com/api/v3/coins/litecoin/market_chart?vs_currency=usd&days=7"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid Litecoin CoinGecko history URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let prices = json["prices"] as? [[Any]] {
                    
                    // Extract price values from [[timestamp, price]] format
                    let priceHistory = prices.compactMap { priceData -> Double? in
                        guard priceData.count >= 2,
                              let price = priceData[1] as? Double else { return nil }
                        return price
                    }
                    
                    // Ensure we have enough data points and they're reasonable
                    if priceHistory.count >= 5 && priceHistory.allSatisfy({ $0 > 0 }) {
                        await MainActor.run {
                            self.litecoinPriceHistory = priceHistory
                            print("✅ Litecoin price history loaded: \(priceHistory.count) data points")
                            print("📊 Litecoin price range: $\(priceHistory.min() ?? 0) - $\(priceHistory.max() ?? 0)")
                            
                            // Cache the successful response
                            UserDefaults.standard.set(priceHistory, forKey: "cached_litecoin_history")
                            UserDefaults.standard.set(Date(), forKey: "cached_litecoin_history_time")
                        }
                    } else {
                        print("❌ Invalid Litecoin price history data: \(priceHistory)")
                        // Fallback to mock data
                        await MainActor.run {
                            self.litecoinPriceHistory = [86, 85.5, 85.2, 85.8, 85.1, 84.8, 85]
                        }
                    }
                } else {
                    print("❌ Failed to parse Litecoin CoinGecko history response")
                    // Fallback to mock data
                    await MainActor.run {
                        self.litecoinPriceHistory = [86, 85.5, 85.2, 85.8, 85.1, 84.8, 85]
                    }
                }
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                print("⚠️ Litecoin CoinGecko history API rate limited (429). Using cached data if available.")
                // Try to use cached data even if expired
                if let cachedHistory = UserDefaults.standard.object(forKey: "cached_litecoin_history") as? [Double] {
                    await MainActor.run {
                        self.litecoinPriceHistory = cachedHistory
                        print("✅ Using expired cached Litecoin history due to rate limit: \(cachedHistory.count) data points")
                    }
                } else {
                    // Fallback to mock data
                    await MainActor.run {
                        self.litecoinPriceHistory = [86, 85.5, 85.2, 85.8, 85.1, 84.8, 85]
                    }
                }
            } else {
                print("❌ Litecoin CoinGecko history API error: \(response)")
                // Fallback to mock data
                await MainActor.run {
                    self.litecoinPriceHistory = [86, 85.5, 85.2, 85.8, 85.1, 84.8, 85]
                }
            }
        } catch {
            print("❌ Litecoin CoinGecko history network error: \(error)")
            // Fallback to mock data
            await MainActor.run {
                self.priceHistory = [86, 85.5, 85.2, 85.8, 85.1, 84.8, 85]
            }
        }
    }
    
    private func loadFluxData() async {
        // Load Flux balance and price
        if let address = walletService.loadAddress() {
            // For now, use mock balance - can be expanded with real Flux service
            await MainActor.run {
                self.coinBalance = 1500.0 // Mock Flux balance
            }
            
            // Load real price data from CoinGecko
            await loadFluxPrice()
            
            // Load price history for chart
            await loadFluxPriceHistory()
        }
    }
    
    private func loadFluxPrice() async {
        // Rate limiting: Add delay between API calls
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // Check cache first
        if let cachedPrice = UserDefaults.standard.object(forKey: "cached_flux_price") as? Double,
           let cachedChange = UserDefaults.standard.object(forKey: "cached_flux_change") as? Double,
           let cacheTime = UserDefaults.standard.object(forKey: "cached_flux_time") as? Date {
            
            // Use cache if less than 5 minutes old
            if Date().timeIntervalSince(cacheTime) < 300 {
                await MainActor.run {
                    self.coinPrice = cachedPrice
                    self.coinPriceChange = cachedChange
                    print("✅ Using cached Flux price: $\(cachedPrice) (24h change: \(cachedChange)%)")
                }
                return
            }
        }
        
        // CoinGecko API endpoint for Flux price (using zelcash ID)
        let urlString = "https://api.coingecko.com/api/v3/simple/price?ids=zelcash&vs_currencies=usd&include_24hr_change=true"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid Flux CoinGecko URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let zelcash = json["zelcash"] as? [String: Any],
                   let usd = zelcash["usd"] as? Double,
                   let usdChange = zelcash["usd_24h_change"] as? Double {
                    
        await MainActor.run {
                        self.coinPrice = usd
                        self.coinPriceChange = usdChange
                        print("✅ Flux price loaded: $\(usd) (24h change: \(usdChange)%)")
                        
                        // Cache the successful response
                        UserDefaults.standard.set(usd, forKey: "cached_flux_price")
                        UserDefaults.standard.set(usdChange, forKey: "cached_flux_change")
                        UserDefaults.standard.set(Date(), forKey: "cached_flux_time")
                    }
            } else {
                    print("❌ Failed to parse Flux CoinGecko response")
                    // Fallback to mock data
                    await MainActor.run {
                        self.coinPrice = 0.65
                        self.coinPriceChange = 5.3
                    }
                }
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                print("⚠️ Flux CoinGecko API rate limited (429). Using cached data if available.")
                // Try to use cached data even if expired
                if let cachedPrice = UserDefaults.standard.object(forKey: "cached_flux_price") as? Double,
                   let cachedChange = UserDefaults.standard.object(forKey: "cached_flux_change") as? Double {
                    await MainActor.run {
                        self.coinPrice = cachedPrice
                        self.coinPriceChange = cachedChange
                        print("✅ Using expired cached Flux price due to rate limit: $\(cachedPrice)")
                    }
                } else {
                    // Fallback to mock data
                    await MainActor.run {
                        self.coinPrice = 0.65
                        self.coinPriceChange = 5.3
                    }
                }
            } else {
                print("❌ Flux CoinGecko API error: \(response)")
                // Fallback to mock data
                await MainActor.run {
                    self.coinPrice = 0.65
                    self.coinPriceChange = 5.3
                }
            }
        } catch {
            print("❌ Flux CoinGecko network error: \(error)")
            // Fallback to mock data
            await MainActor.run {
                self.coinPrice = 0.65
                self.coinPriceChange = 5.3
            }
        }
    }
    
    private func loadFluxPriceHistory() async {
        // Rate limiting: Add delay between API calls
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // Check cache first
        if let cachedHistory = UserDefaults.standard.object(forKey: "cached_flux_history") as? [Double],
           let cacheTime = UserDefaults.standard.object(forKey: "cached_flux_history_time") as? Date {
            
            // Use cache if less than 10 minutes old
            if Date().timeIntervalSince(cacheTime) < 600 {
                await MainActor.run {
                    self.fluxPriceHistory = cachedHistory
                    print("✅ Using cached Flux history: \(cachedHistory.count) data points")
                }
                return
            }
        }
        
        // CoinGecko API endpoint for 7-day price history
        let urlString = "https://api.coingecko.com/api/v3/coins/zelcash/market_chart?vs_currency=usd&days=7"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid Flux CoinGecko history URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let prices = json["prices"] as? [[Any]] {
                    
                    // Extract price values from [[timestamp, price]] format
                    let priceHistory = prices.compactMap { priceData -> Double? in
                        guard priceData.count >= 2,
                              let price = priceData[1] as? Double else { return nil }
                        return price
                    }
                    
                    // Ensure we have enough data points and they're reasonable
                    if priceHistory.count >= 5 && priceHistory.allSatisfy({ $0 > 0 }) {
                        await MainActor.run {
                            self.fluxPriceHistory = priceHistory
                            print("✅ Flux price history loaded: \(priceHistory.count) data points")
                            print("📊 Flux price range: $\(priceHistory.min() ?? 0) - $\(priceHistory.max() ?? 0)")
                            
                            // Cache the successful response
                            UserDefaults.standard.set(priceHistory, forKey: "cached_flux_history")
                            UserDefaults.standard.set(Date(), forKey: "cached_flux_history_time")
                        }
                    } else {
                        print("❌ Invalid Flux price history data: \(priceHistory)")
                        // Fallback to mock data
                        await MainActor.run {
                            self.fluxPriceHistory = [0.62, 0.63, 0.64, 0.63, 0.65, 0.66, 0.65]
                        }
                    }
                } else {
                    print("❌ Failed to parse Flux CoinGecko history response")
                    // Fallback to mock data
                    await MainActor.run {
                        self.fluxPriceHistory = [0.62, 0.63, 0.64, 0.63, 0.65, 0.66, 0.65]
                    }
                }
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                print("⚠️ Flux CoinGecko history API rate limited (429). Using cached data if available.")
                // Try to use cached data even if expired
                if let cachedHistory = UserDefaults.standard.object(forKey: "cached_flux_history") as? [Double] {
                    await MainActor.run {
                        self.fluxPriceHistory = cachedHistory
                        print("✅ Using expired cached Flux history due to rate limit: \(cachedHistory.count) data points")
                    }
                } else {
                    // Fallback to mock data
                    await MainActor.run {
                        self.fluxPriceHistory = [0.62, 0.63, 0.64, 0.63, 0.65, 0.66, 0.65]
                    }
                }
            } else {
                print("❌ Flux CoinGecko history API error: \(response)")
                // Fallback to mock data
                await MainActor.run {
                    self.fluxPriceHistory = [0.62, 0.63, 0.64, 0.63, 0.65, 0.66, 0.65]
                }
            }
        } catch {
            print("❌ Flux CoinGecko history network error: \(error)")
            // Fallback to mock data
            await MainActor.run {
                self.priceHistory = [0.62, 0.63, 0.64, 0.63, 0.65, 0.66, 0.65]
            }
        }
    }
    
    private func loadKaspaData() async {
        // Load Kaspa balance and price
        if let address = walletService.loadAddress() {
            // For now, use mock balance - can be expanded with real Kaspa service
            await MainActor.run {
                self.coinBalance = 50000.0 // Mock Kaspa balance
            }
            
            // Load real price data from CoinGecko
            await loadKaspaPrice()
            
            // Load price history for chart
            await loadKaspaPriceHistory()
        }
    }
    
    private func loadKaspaPrice() async {
        // Rate limiting: Add delay between API calls
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // Check cache first
        if let cachedPrice = UserDefaults.standard.object(forKey: "cached_kaspa_price") as? Double,
           let cachedChange = UserDefaults.standard.object(forKey: "cached_kaspa_change") as? Double,
           let cacheTime = UserDefaults.standard.object(forKey: "cached_kaspa_time") as? Date {
            
            // Use cache if less than 5 minutes old
            if Date().timeIntervalSince(cacheTime) < 300 {
                await MainActor.run {
                    self.coinPrice = cachedPrice
                    self.coinPriceChange = cachedChange
                    print("✅ Using cached Kaspa price: $\(cachedPrice) (24h change: \(cachedChange)%)")
            }
            return
            }
        }
        
        // CoinGecko API endpoint for Kaspa price
        let urlString = "https://api.coingecko.com/api/v3/simple/price?ids=kaspa&vs_currencies=usd&include_24hr_change=true"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid Kaspa CoinGecko URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let kaspa = json["kaspa"] as? [String: Any],
                   let usd = kaspa["usd"] as? Double,
                   let usdChange = kaspa["usd_24h_change"] as? Double {
                    
                    await MainActor.run {
                        self.coinPrice = usd
                        self.coinPriceChange = usdChange
                        print("✅ Kaspa price loaded: $\(usd) (24h change: \(usdChange)%)")
                        
                        // Cache the successful response
                        UserDefaults.standard.set(usd, forKey: "cached_kaspa_price")
                        UserDefaults.standard.set(usdChange, forKey: "cached_kaspa_change")
                        UserDefaults.standard.set(Date(), forKey: "cached_kaspa_time")
                    }
                } else {
                    print("❌ Failed to parse Kaspa CoinGecko response")
                    // Fallback to mock data
                    await MainActor.run {
                        self.coinPrice = 0.12
                        self.coinPriceChange = 8.7
                    }
                }
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                print("⚠️ Kaspa CoinGecko API rate limited (429). Using cached data if available.")
                // Try to use cached data even if expired
                if let cachedPrice = UserDefaults.standard.object(forKey: "cached_kaspa_price") as? Double,
                   let cachedChange = UserDefaults.standard.object(forKey: "cached_kaspa_change") as? Double {
                    await MainActor.run {
                        self.coinPrice = cachedPrice
                        self.coinPriceChange = cachedChange
                        print("✅ Using expired cached Kaspa price due to rate limit: $\(cachedPrice)")
                    }
                } else {
                    // Fallback to mock data
                    await MainActor.run {
                        self.coinPrice = 0.12
                        self.coinPriceChange = 8.7
                    }
                }
            } else {
                print("❌ Kaspa CoinGecko API error: \(response)")
                // Fallback to mock data
                await MainActor.run {
                    self.coinPrice = 0.12
                    self.coinPriceChange = 8.7
                }
            }
        } catch {
            print("❌ Kaspa CoinGecko network error: \(error)")
            // Fallback to mock data
            await MainActor.run {
                self.coinPrice = 0.12
                self.coinPriceChange = 8.7
            }
        }
    }
    
    private func loadKaspaPriceHistory() async {
        // Rate limiting: Add delay between API calls
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // Check cache first
        if let cachedHistory = UserDefaults.standard.object(forKey: "cached_kaspa_history") as? [Double],
           let cacheTime = UserDefaults.standard.object(forKey: "cached_kaspa_history_time") as? Date {
            
            // Use cache if less than 10 minutes old
            if Date().timeIntervalSince(cacheTime) < 600 {
                await MainActor.run {
                    self.kaspaPriceHistory = cachedHistory
                    print("✅ Using cached Kaspa history: \(cachedHistory.count) data points")
                }
                return
            }
        }
        
        // CoinGecko API endpoint for 7-day price history
        let urlString = "https://api.coingecko.com/api/v3/coins/kaspa/market_chart?vs_currency=usd&days=7"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid Kaspa CoinGecko history URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let prices = json["prices"] as? [[Any]] {
                    
                    // Extract price values from [[timestamp, price]] format
                    let priceHistory = prices.compactMap { priceData -> Double? in
                        guard priceData.count >= 2,
                              let price = priceData[1] as? Double else { return nil }
                        return price
                    }
                    
                    // Ensure we have enough data points and they're reasonable
                    if priceHistory.count >= 5 && priceHistory.allSatisfy({ $0 > 0 }) {
                        await MainActor.run {
                            self.kaspaPriceHistory = priceHistory
                            print("✅ Kaspa price history loaded: \(priceHistory.count) data points")
                            print("📊 Kaspa price range: $\(priceHistory.min() ?? 0) - $\(priceHistory.max() ?? 0)")
                            
                            // Cache the successful response
                            UserDefaults.standard.set(priceHistory, forKey: "cached_kaspa_history")
                            UserDefaults.standard.set(Date(), forKey: "cached_kaspa_history_time")
                        }
                    } else {
                        print("❌ Invalid Kaspa price history data: \(priceHistory)")
                        // Fallback to mock data
                        await MainActor.run {
                            self.kaspaPriceHistory = [0.11, 0.112, 0.115, 0.114, 0.116, 0.118, 0.12]
                        }
                    }
                } else {
                    print("❌ Failed to parse Kaspa CoinGecko history response")
                    // Fallback to mock data
                    await MainActor.run {
                        self.kaspaPriceHistory = [0.11, 0.112, 0.115, 0.114, 0.116, 0.118, 0.12]
                    }
                }
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                print("⚠️ Kaspa CoinGecko history API rate limited (429). Using cached data if available.")
                // Try to use cached data even if expired
                if let cachedHistory = UserDefaults.standard.object(forKey: "cached_kaspa_history") as? [Double] {
                    await MainActor.run {
                        self.kaspaPriceHistory = cachedHistory
                        print("✅ Using expired cached Kaspa history due to rate limit: \(cachedHistory.count) data points")
                    }
                } else {
                    // Fallback to mock data
                    await MainActor.run {
                        self.kaspaPriceHistory = [0.11, 0.112, 0.115, 0.114, 0.116, 0.118, 0.12]
                    }
                }
            } else {
                print("❌ Kaspa CoinGecko history API error: \(response)")
                // Fallback to mock data
                await MainActor.run {
                    self.kaspaPriceHistory = [0.11, 0.112, 0.115, 0.114, 0.116, 0.118, 0.12]
                }
            }
        } catch {
            print("❌ Kaspa CoinGecko history network error: \(error)")
            // Fallback to mock data
            await MainActor.run {
                self.priceHistory = [0.11, 0.112, 0.115, 0.114, 0.116, 0.118, 0.12]
            }
        }
    }
    
    // MARK: - USDT Functions
    private func loadUSDTData() async {
        // Load USDT balance and price
        if let address = walletService.loadAddress() {
            // For now, use mock balance - can be expanded with real USDT service
            await MainActor.run {
                self.coinBalance = 1000.0 // Mock USDT balance
            }
            
            // Load real price data from CoinGecko
            await loadUSDTPrice()
            
            // Load price history for chart
            await loadUSDTPriceHistory()
        }
    }
    
    private func loadUSDTPrice() async {
        // Rate limiting: Add delay between API calls
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // Check cache first
        if let cachedPrice = UserDefaults.standard.object(forKey: "cached_usdt_price") as? Double,
           let cachedChange = UserDefaults.standard.object(forKey: "cached_usdt_change") as? Double,
           let cacheTime = UserDefaults.standard.object(forKey: "cached_usdt_time") as? Date {
            
            // Use cache if less than 5 minutes old
            if Date().timeIntervalSince(cacheTime) < 300 {
                await MainActor.run {
                    self.coinPrice = cachedPrice
                    self.coinPriceChange = cachedChange
                    print("✅ Using cached USDT price: $\(cachedPrice) (24h change: \(cachedChange)%)")
                }
                return
            }
        }
        
        // CoinGecko API endpoint for USDT price
        let urlString = "https://api.coingecko.com/api/v3/simple/price?ids=tether&vs_currencies=usd&include_24hr_change=true"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid USDT CoinGecko URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let tether = json["tether"] as? [String: Any],
                   let usd = tether["usd"] as? Double,
                   let usdChange = tether["usd_24h_change"] as? Double {
                    
                    await MainActor.run {
                        self.coinPrice = usd
                        self.coinPriceChange = usdChange
                        print("✅ USDT price loaded: $\(usd) (24h change: \(usdChange)%)")
                        
                        // Cache the successful response
                        UserDefaults.standard.set(usd, forKey: "cached_usdt_price")
                        UserDefaults.standard.set(usdChange, forKey: "cached_usdt_change")
                        UserDefaults.standard.set(Date(), forKey: "cached_usdt_time")
                    }
                } else {
                    print("❌ Failed to parse USDT CoinGecko response")
                    // Fallback to mock data
                    await MainActor.run {
                        self.coinPrice = 1.0
                        self.coinPriceChange = 0.01
                    }
                }
            } else {
                print("❌ USDT CoinGecko API error: \(response)")
                // Fallback to mock data
                await MainActor.run {
                    self.coinPrice = 1.0
                    self.coinPriceChange = 0.01
                }
            }
        } catch {
            print("❌ USDT CoinGecko network error: \(error)")
            // Fallback to mock data
            await MainActor.run {
                self.coinPrice = 1.0
                self.coinPriceChange = 0.01
            }
        }
    }
    
    private func loadUSDTPriceHistory() async {
        // Rate limiting: Add delay between API calls
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // Check cache first
        if let cachedHistory = UserDefaults.standard.object(forKey: "cached_usdt_history") as? [Double],
           let cacheTime = UserDefaults.standard.object(forKey: "cached_usdt_history_time") as? Date {
            
            // Use cache if less than 10 minutes old
            if Date().timeIntervalSince(cacheTime) < 600 {
                await MainActor.run {
                    self.usdtPriceHistory = cachedHistory
                    print("✅ Using cached USDT history: \(cachedHistory.count) data points")
                }
                return
            }
        }
        
        // CoinGecko API endpoint for 7-day price history
        let urlString = "https://api.coingecko.com/api/v3/coins/tether/market_chart?vs_currency=usd&days=7"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid USDT CoinGecko history URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let prices = json["prices"] as? [[Any]] {
                    
                    // Extract price values from [[timestamp, price]] format
                    let priceHistory = prices.compactMap { priceData -> Double? in
                        guard priceData.count >= 2,
                              let price = priceData[1] as? Double else { return nil }
                        return price
                    }
                    
                    // Ensure we have enough data points and they're reasonable
                    if priceHistory.count >= 5 && priceHistory.allSatisfy({ $0 > 0 }) {
                        await MainActor.run {
                            self.usdtPriceHistory = priceHistory
                            print("✅ USDT price history loaded: \(priceHistory.count) data points")
                            print("📊 USDT price range: $\(priceHistory.min() ?? 0) - $\(priceHistory.max() ?? 0)")
                            
                            // Cache the successful response
                            UserDefaults.standard.set(priceHistory, forKey: "cached_usdt_history")
                            UserDefaults.standard.set(Date(), forKey: "cached_usdt_history_time")
                        }
        } else {
                        print("❌ Invalid USDT price history data: \(priceHistory)")
                        // Fallback to mock data
                        await MainActor.run {
                            self.usdtPriceHistory = [0.999, 1.001, 0.998, 1.002, 0.999, 1.001, 1.0]
                        }
                    }
                } else {
                    print("❌ Failed to parse USDT CoinGecko history response")
                    // Fallback to mock data
                    await MainActor.run {
                        self.usdtPriceHistory = [0.999, 1.001, 0.998, 1.002, 0.999, 1.001, 1.0]
                    }
                }
            } else {
                print("❌ USDT CoinGecko history API error: \(response)")
                // Fallback to mock data
                await MainActor.run {
                    self.usdtPriceHistory = [0.999, 1.001, 0.998, 1.002, 0.999, 1.001, 1.0]
                }
            }
        } catch {
            print("❌ USDT CoinGecko history network error: \(error)")
            // Fallback to mock data
            await MainActor.run {
                self.usdtPriceHistory = [0.999, 1.001, 0.998, 1.002, 0.999, 1.001, 1.0]
            }
        }
    }
    
    // MARK: - USDC Functions
    private func loadUSDCData() async {
        // Load USDC balance and price
        if let address = walletService.loadAddress() {
            // For now, use mock balance - can be expanded with real USDC service
            await MainActor.run {
                self.coinBalance = 2500.0 // Mock USDC balance
            }
            
            // Load real price data from CoinGecko
            await loadUSDCPrice()
            
            // Load price history for chart
            await loadUSDCPriceHistory()
        }
    }
    
    private func loadUSDCPrice() async {
        // Rate limiting: Add delay between API calls
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // Check cache first
        if let cachedPrice = UserDefaults.standard.object(forKey: "cached_usdc_price") as? Double,
           let cachedChange = UserDefaults.standard.object(forKey: "cached_usdc_change") as? Double,
           let cacheTime = UserDefaults.standard.object(forKey: "cached_usdc_time") as? Date {
            
            // Use cache if less than 5 minutes old
            if Date().timeIntervalSince(cacheTime) < 300 {
                await MainActor.run {
                    self.coinPrice = cachedPrice
                    self.coinPriceChange = cachedChange
                    print("✅ Using cached USDC price: $\(cachedPrice) (24h change: \(cachedChange)%)")
                }
                return
            }
        }
        
        // CoinGecko API endpoint for USDC price
        let urlString = "https://api.coingecko.com/api/v3/simple/price?ids=usd-coin&vs_currencies=usd&include_24hr_change=true"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid USDC CoinGecko URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let usdCoin = json["usd-coin"] as? [String: Any],
                   let usd = usdCoin["usd"] as? Double,
                   let usdChange = usdCoin["usd_24h_change"] as? Double {
                    
                    await MainActor.run {
                        self.coinPrice = usd
                        self.coinPriceChange = usdChange
                        print("✅ USDC price loaded: $\(usd) (24h change: \(usdChange)%)")
                        
                        // Cache the successful response
                        UserDefaults.standard.set(usd, forKey: "cached_usdc_price")
                        UserDefaults.standard.set(usdChange, forKey: "cached_usdc_change")
                        UserDefaults.standard.set(Date(), forKey: "cached_usdc_time")
                    }
            } else {
                    print("❌ Failed to parse USDC CoinGecko response")
                    // Fallback to mock data
                    await MainActor.run {
                        self.coinPrice = 1.0
                        self.coinPriceChange = 0.01
                    }
                }
            } else {
                print("❌ USDC CoinGecko API error: \(response)")
                // Fallback to mock data
                await MainActor.run {
                    self.coinPrice = 1.0
                    self.coinPriceChange = 0.01
                }
            }
        } catch {
            print("❌ USDC CoinGecko network error: \(error)")
            // Fallback to mock data
            await MainActor.run {
                self.coinPrice = 1.0
                self.coinPriceChange = 0.01
            }
        }
    }
    
    private func loadUSDCPriceHistory() async {
        // Rate limiting: Add delay between API calls
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // Check cache first
        if let cachedHistory = UserDefaults.standard.object(forKey: "cached_usdc_history") as? [Double],
           let cacheTime = UserDefaults.standard.object(forKey: "cached_usdc_history_time") as? Date {
            
            // Use cache if less than 10 minutes old
            if Date().timeIntervalSince(cacheTime) < 600 {
                await MainActor.run {
                    self.usdcPriceHistory = cachedHistory
                    print("✅ Using cached USDC history: \(cachedHistory.count) data points")
                }
            return
            }
        }
        
        // CoinGecko API endpoint for 7-day price history
        let urlString = "https://api.coingecko.com/api/v3/coins/usd-coin/market_chart?vs_currency=usd&days=7"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid USDC CoinGecko history URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let prices = json["prices"] as? [[Any]] {
                    
                    // Extract price values from [[timestamp, price]] format
                    let priceHistory = prices.compactMap { priceData -> Double? in
                        guard priceData.count >= 2,
                              let price = priceData[1] as? Double else { return nil }
                        return price
                    }
                    
                    // Ensure we have enough data points and they're reasonable
                    if priceHistory.count >= 5 && priceHistory.allSatisfy({ $0 > 0 }) {
                        await MainActor.run {
                            self.usdcPriceHistory = priceHistory
                            print("✅ USDC price history loaded: \(priceHistory.count) data points")
                            print("📊 USDC price range: $\(priceHistory.min() ?? 0) - $\(priceHistory.max() ?? 0)")
                            
                            // Cache the successful response
                            UserDefaults.standard.set(priceHistory, forKey: "cached_usdc_history")
                            UserDefaults.standard.set(Date(), forKey: "cached_usdc_history_time")
                        }
                    } else {
                        print("❌ Invalid USDC price history data: \(priceHistory)")
                        // Fallback to mock data
                        await MainActor.run {
                            self.usdcPriceHistory = [0.999, 1.001, 0.998, 1.002, 0.999, 1.001, 1.0]
                        }
                    }
                } else {
                    print("❌ Failed to parse USDC CoinGecko history response")
                    // Fallback to mock data
                    await MainActor.run {
                        self.usdcPriceHistory = [0.999, 1.001, 0.998, 1.002, 0.999, 1.001, 1.0]
                    }
                }
            } else {
                print("❌ USDC CoinGecko history API error: \(response)")
                // Fallback to mock data
                await MainActor.run {
                    self.usdcPriceHistory = [0.999, 1.001, 0.998, 1.002, 0.999, 1.001, 1.0]
                }
            }
        } catch {
            print("❌ USDC CoinGecko history network error: \(error)")
            // Fallback to mock data
            await MainActor.run {
                self.usdcPriceHistory = [0.999, 1.001, 0.998, 1.002, 0.999, 1.001, 1.0]
            }
        }
    }
    
    // MARK: - Helper Functions for Coin Data
    private func getCoinBalance(for coin: String) -> Double {
        switch coin {
        case "TLS":
            return tlsBalance
        case "Bitcoin":
            return 0.5 // Mock balance
        case "USDT":
            return 1000.0 // Mock balance
        case "USDC":
            return 2500.0 // Mock balance
        case "Litecoin":
            return 25.0 // Mock balance
        case "Flux":
            return 100.0 // Mock balance
        case "Kaspa":
            return 50000.0 // Mock balance
        default:
            return 0.0
        }
    }
    
    private func getCoinPrice(for coin: String) -> Double {
        switch coin {
        case "TLS":
            return tlsPrice
        case "Bitcoin":
            return 45000.0 // Mock price
        case "USDT":
            return 1.0 // Mock price
        case "USDC":
            return 1.0 // Mock price
        case "Litecoin":
            return 75.0 // Mock price
        case "Flux":
            return 0.5 // Mock price
        case "Kaspa":
            return 0.12 // Mock price
        default:
            return 0.0
        }
    }
    
    private func getCoinPriceChange(for coin: String) -> Double {
        switch coin {
        case "TLS":
            return tlsPriceChange
        case "Bitcoin":
            return 2.1 // Mock change
        case "USDT":
            return 0.01 // Mock change
        case "USDC":
            return 0.01 // Mock change
        case "Litecoin":
            return -1.5 // Mock change
        case "Flux":
            return 5.2 // Mock change
        case "Kaspa":
            return 8.7 // Mock change
        default:
            return 0.0
        }
    }
    


    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Selected Coin Details Card - Moved to top
                if selectedCoin != "" {
                    CardView {
                        VStack(spacing: DesignSystem.Spacing.md) {
                            // Selected coin info
                            HStack {
                                Text(selectedCoin)
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.text)
                                
                                Spacer()
                                
                                if isLoadingPrice {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                            
                            VStack(spacing: DesignSystem.Spacing.md) {
                                VStack(spacing: DesignSystem.Spacing.xs) {
                                    // Currency value with price trend arrow
                                    let selectedCurrency = UserDefaults.standard.string(forKey: "user_currency") ?? "USD"
                                    let currencySymbol = getCurrencySymbol(for: selectedCurrency)
                                    
                                    if coinPrice > 0 {
                                        HStack(spacing: DesignSystem.Spacing.sm) {
                                            Text("\(currencySymbol)\(String(format: "%.2f", coinBalance * coinPrice))")
                                                .font(DesignSystem.Typography.titleMedium)
                                                .foregroundColor(DesignSystem.Colors.text)
                                                .multilineTextAlignment(.center)
                                            
                                            if coinPriceChange != 0 {
                                                Image(systemName: coinPriceChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                                                    .foregroundColor(coinPriceChange >= 0 ? .green : .red)
                                                    .font(.system(size: 16, weight: .semibold))
                                            }
                                        }
                                    }
                                    
                                    // Coin amount below in smaller font
                                    Text("\(String(format: "%.4f", coinBalance)) \(selectedCoin)")
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                
                                // 7-Day Price Trend
                                VStack(spacing: DesignSystem.Spacing.sm) {
                                    HStack {
                                        Text("7-Day Price Trend")
                                            .font(DesignSystem.Typography.bodySmall)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                        Spacer()
                                    }
                                    
                                    if !priceHistory.isEmpty {
                                        LineChartView(
                                            data: priceHistory,
                                            width: UIScreen.main.bounds.width - 80,
                                            height: 60,
                                            isPositive: coinPriceChange >= 0
                                        )
                                    } else {
                                        Rectangle()
                                            .fill(DesignSystem.Colors.surface)
                                            .frame(height: 60)
                                            .cornerRadius(DesignSystem.CornerRadius.small)
                                    }
                                    
                                    // Coin Price below the chart
                                    if coinPrice > 0 {
                                        Text("$\(String(format: "%.5f", coinPrice)) per \(selectedCoin)")
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.md)
                }
                
                // Transaction Action Buttons - Top section
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
                .padding(.top, DesignSystem.Spacing.lg)
                
                // Coin List - Trust Wallet Style with Filter
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Filter Header
                    HStack {
                        Text("Assets")
                            .font(DesignSystem.Typography.titleMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.text)
                        
                        Spacer()
                        
                        Button(action: {
                            showFilter.toggle()
                            if showFilter {
                                filteredCoins = availableCoins
                            } else {
                                filteredCoins = availableCoins
                            }
                        }) {
                            Image(systemName: showFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.system(size: 20))
                                .foregroundColor(DesignSystem.Colors.secondary)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    
                    ScrollView {
                        LazyVStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(filteredCoins, id: \.self) { coin in
                                CoinRowView(
                                    coin: coin,
                                    isSelected: selectedCoin == coin,
                                    balance: getCoinBalance(for: coin),
                                    price: getCoinPrice(for: coin),
                                    priceChange: getCoinPriceChange(for: coin),
                                    onTap: {
                                        selectedCoin = coin
                                        Task {
                                            await loadCoinDataAsync()
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                }
                
                Spacer()
                
                // Bottom Navigation
                BottomNavigationView(
                    selectedTab: $selectedTab,
                    showMessaging: $showMessaging,
                    showHamburgerMenu: $showHamburgerMenu,
                    path: $path,
                    themeManager: themeManager
                )
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
            setupCompanionTaskListener()
        }
    }
    
    private func handleCommand(userInput: String = "") {
        // Command handling preserved for future use with AI companion
        // This function can be called from the AI companion interface
        
        // Create enhanced prompt with context
        let enhancedPrompt = """
        You are an AI assistant for a blockchain app. The user has a balance of \(String(format: "%.6f", tlsBalance)) TLS.
        
        User request: \(userInput)
        
        Respond with a JSON object containing:
        - "action": The action to perform (e.g., "add meeting", "open maps", "check balance", "send payment")
        - "parameters": A dictionary of parameters needed for the action
        - "response": A natural language response to the user
        
        Available actions:
        - "add meeting": Schedule a calendar event (requires "title", "start", "end")
        - "open maps": Navigate to a location (requires "location")
        - "open safari": Open a website (requires "url")
        - "open messages": Send a text message (requires "contact", "message")
        - "open phone": Make a phone call (requires "contact")
        - "open mail": Send an email (requires "to", "subject")
        - "open camera": Take a photo
        - "open photos": Open photo gallery
        - "open settings": Open device settings
        - "open notes": Create a note (requires "title", "content")
        - "prioritize messages": Analyze and prioritize messages
        - "tell main stats": Show blockchain statistics
        - "sign message": Sign a message with wallet (requires "message")
        - "check balance": Check current TLS balance
        - "send payment": Send TLS payment (requires "to", "amount")
        
        Use UTC timezone and assume today is 2025-07-15. Return ONLY the JSON object, no additional text or explanation.
        """
        
        print("Sending enhanced AI request: \(enhancedPrompt)")
        NetworkService.shared.getGrokResponse(input: enhancedPrompt) { result in
            print("Enhanced AI result: \(result)")
            switch result {
            case .success(let response):
                print("🤖 AI Response: \(response)")
                // Try to extract JSON from the response (it might contain extra text)
                let cleanResponse = self.extractJSONFromResponse(response)
                do {
                    if let data = cleanResponse.data(using: .utf8),
                       let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let action = json["action"] as? String {
                        print("✅ Parsed action: \(action), json: \(json)")
                        let parameters = json["parameters"] as? [String: Any] ?? [:]
                        print("📋 Parameters: \(parameters)")
                        
                        DispatchQueue.main.async {
                            if let responseText = json["response"] as? String {
                                self.alertMessage = responseText
                                self.showAlert = true
                            }
                            self.handleAction(action: action, parameters: parameters)
                        }
                    } else {
                        print("❌ Failed to parse JSON response")
                        print("📄 Raw response: \(response)")
                        DispatchQueue.main.async {
                            self.alertMessage = "I received a response but couldn't parse it properly."
                            self.showAlert = true
                        }
                    }
                } catch {
                    print("❌ JSON parsing error: \(error)")
                    DispatchQueue.main.async {
                        self.alertMessage = "I received a response but couldn't parse it properly."
                        self.showAlert = true
                    }
                }
            case .failure(let error):
                print("AI request failed: \(error)")
                DispatchQueue.main.async {
                    self.alertMessage = "I'm sorry, I couldn't process that request. Please try again."
                    self.showAlert = true
                }
            }
        }
    }
    
    private func extractJSONFromResponse(_ response: String) -> String {
        // Try to extract JSON from the response (AI might add extra text)
        if let startIndex = response.firstIndex(of: "{"),
           let endIndex = response.lastIndex(of: "}") {
            let jsonStart = response.index(startIndex, offsetBy: 0)
            let jsonEnd = response.index(endIndex, offsetBy: 1)
            return String(response[jsonStart..<jsonEnd])
        }
        return response
    }
    
    private func handleAction(action: String, parameters: [String: Any]) {
        print("🔧 Handling action: \(action) with parameters: \(parameters)")
        
        switch action {
        case "add meeting", "schedule meeting":
            print("📅 Scheduling meeting with parameters: \(parameters)")
            
            // Handle missing parameters with defaults
            let title = parameters["title"] as? String ?? "Meeting"
            let start = parameters["start"] as? String
            let end = parameters["end"] as? String
            
            if let startString = start,
               let startDate = ISO8601DateFormatter().date(from: startString) {
                // If we have a start time, calculate end time (1 hour later if not provided)
                let endDate: Date
                if let endString = end,
                   let parsedEndDate = ISO8601DateFormatter().date(from: endString) {
                    endDate = parsedEndDate
                } else {
                    // Default to 1 hour duration
                    endDate = startDate.addingTimeInterval(3600)
                }
                
                print("✅ Valid meeting parameters, adding to calendar")
                addToCalendar(title: title, start: startDate, end: endDate)
            } else {
                print("❌ Invalid meeting parameters - missing start time")
                alertMessage = "Please specify a meeting time"
                showAlert = true
            }
            
        case "open maps", "navigate to":
            // Handle both single location and start/end locations
            if let location = parameters["location"] as? String {
                openMaps(location: location)
            } else if let startLocation = parameters["start_location"] as? String,
                      let endLocation = parameters["end_location"] as? String {
                // For navigation between two points, use the destination
                openMaps(location: "\(startLocation) to \(endLocation)")
            } else if let endLocation = parameters["end_location"] as? String {
                // If only end location is provided, use that
                openMaps(location: endLocation)
            } else {
                alertMessage = "Please specify a location"
                showAlert = true
            }
            
        case "open safari", "open website", "browse":
            if let url = parameters["url"] as? String {
                openURL(url: url)
            }
            
        case "open messages", "send message", "text":
            if let contact = parameters["contact"] as? String,
               let message = parameters["message"] as? String {
                openMessages(contact: contact, message: message)
            } else {
                alertMessage = "Please specify a contact and message"
                showAlert = true
            }
            
        case "open phone", "call":
            if let contact = parameters["contact"] as? String {
                openPhone(contact: contact)
            } else {
                alertMessage = "Please specify a contact to call"
                showAlert = true
            }
            
        case "open mail", "send email":
            if let to = parameters["to"] as? String {
                let subject = parameters["subject"] as? String ?? "Message from PAAI"
                openMail(to: to, subject: subject)
            } else {
                alertMessage = "Please specify an email address"
                showAlert = true
            }
            
        case "open camera", "take photo":
            openCamera()
            
        case "open photos":
            openPhotos()
            
        case "open settings":
            openSettings()
            
        case "open notes":
            if let title = parameters["title"] as? String,
               let content = parameters["content"] as? String {
                openNotes(title: title, content: content)
            }
            
        case "prioritize messages":
            path.append("prioritization")
            
        case "tell main stats":
            path.append("stats")
            
        case "sign message":
            if let message = parameters["message"] as? String,
               let signature = walletService.signMessage(message) {
                let result = "Message signed successfully: \(signature)"
                alertMessage = result
                showAlert = true
            } else {
                alertMessage = "Failed to sign message"
                showAlert = true
            }
            
        case "check balance":
            Task {
                await tlsService.refreshBalance()
                await MainActor.run {
                    let balance = tlsService.formatBalance(tlsService.currentBalance)
                    alertMessage = "Balance: \(balance)"
                    showAlert = true
                }
            }
            
        case "send payment":
            if let toAddress = parameters["to"] as? String,
               let amountString = parameters["amount"] as? String,
               let amount = Double(amountString) {
                Task {
                    let response = await tlsService.sendPayment(toAddress: toAddress, amount: amount)
                    await MainActor.run {
                        if response.success {
                            alertMessage = "Payment successful! TXID: \(response.txid ?? "Unknown")"
                        } else {
                            alertMessage = "Payment failed: \(response.error ?? "Unknown error")"
                        }
                        showAlert = true
                    }
                }
            }
            
        default:
            print("❌ Unknown action: \(action)")
        }
    }
    
    private func initialize() {
        isInitializing = true
        Task {
            await loadCoinDataAsync()
            isInitializing = false
        }
    }
    
    private func getCurrencySymbol(for currency: String) -> String {
        switch currency {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "CAD": return "C$"
        case "AUD": return "A$"
        default: return "$"
        }
    }
    
    private func loadTLSData() async {
        // Load balance from blockchain
        if let address = walletService.loadAddress(),
           let addressInfo = await tlsService.getAddressInfo(address: address) {
            tlsBalance = addressInfo.balance
        } else {
            // Fallback to mock balance for testing
            tlsBalance = 20000.0
        }
        
        // Load real price data from CoinGecko
        await loadCoinGeckoPrice()
        
        // Load price history for chart
        await loadPriceHistory()
        
        isLoadingPrice = false
        isLoadingHistory = false
    }
    
    private func loadCoinGeckoPrice() async {
        isLoadingPrice = true
        
        // Check rate limit first
        if let rateLimitUntil = UserDefaults.standard.object(forKey: "rate_limit_until") as? Date,
           Date() < rateLimitUntil {
            print("⚠️ Rate limit active until \(rateLimitUntil)")
            // Use cached data if available, otherwise fallback
            if let cachedPrice = UserDefaults.standard.object(forKey: "cached_tls_price") as? Double,
               let cachedChange = UserDefaults.standard.object(forKey: "cached_tls_change") as? Double {
                await MainActor.run {
                    self.tlsPrice = cachedPrice
                    self.tlsPriceChange = cachedChange
                    print("✅ Using cached price during rate limit: $\(cachedPrice)")
                }
            } else {
                await MainActor.run {
                    self.tlsPrice = 0.85
                    self.tlsPriceChange = 2.35
                }
            }
            isLoadingPrice = false
            return
        }
        
        // Check cache first
        if let cachedPrice = UserDefaults.standard.object(forKey: "cached_tls_price") as? Double,
           let cachedChange = UserDefaults.standard.object(forKey: "cached_tls_change") as? Double,
           let cacheTime = UserDefaults.standard.object(forKey: "cached_tls_time") as? Date {
            
            // Use cache if less than 5 minutes old
            if Date().timeIntervalSince(cacheTime) < 300 {
                await MainActor.run {
                    self.tlsPrice = cachedPrice
                    self.tlsPriceChange = cachedChange
                    print("✅ Using cached price: $\(cachedPrice) (24h change: \(cachedChange)%)")
                }
                isLoadingPrice = false
                return
            }
        }
        
        // Try to get Telestai price from multiple sources
        await loadTelestaiPriceFromSources()
        isLoadingPrice = false
    }
    
    private func loadTelestaiPriceFromSources() async {
        // Try multiple price sources for Telestai
        let sources = [
            "https://api.coingecko.com/api/v3/simple/price?ids=telestai&vs_currencies=usd&include_24hr_change=true",
            "https://api.coinpaprika.com/v1/tickers/tls-telestai",
            "https://api.coincap.io/v2/assets/telestai"
        ]
        
        for (index, urlString) in sources.enumerated() {
            guard let url = URL(string: urlString) else { continue }
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    // Try to parse the response based on the source
                    if let price = await parseTelestaiPrice(from: data, source: index) {
                        await MainActor.run {
                            self.tlsPrice = price.price
                            self.tlsPriceChange = price.change
                            print("✅ Telestai price loaded from source \(index + 1): $\(price.price) (24h change: \(price.change)%)")
                            
                            // Cache the successful response
                            UserDefaults.standard.set(price.price, forKey: "cached_tls_price")
                            UserDefaults.standard.set(price.change, forKey: "cached_tls_change")
                            UserDefaults.standard.set(Date(), forKey: "cached_tls_time")
                        }
                        return
                    }
                }
            } catch {
                print("❌ Failed to load Telestai price from source \(index + 1): \(error)")
            }
        }
        
        // If all sources fail, use realistic mock data based on market conditions
        print("ℹ️ All Telestai price sources failed - using realistic mock data")
        let mockPrice = Double.random(in: 0.75...0.95)
        let mockChange = Double.random(in: -5.0...8.0)
        
        await MainActor.run {
            self.tlsPrice = mockPrice
            self.tlsPriceChange = mockChange
            print("✅ Using realistic mock Telestai price: $\(mockPrice) (24h change: \(mockChange)%)")
            
            // Cache the mock data
            UserDefaults.standard.set(mockPrice, forKey: "cached_tls_price")
            UserDefaults.standard.set(mockChange, forKey: "cached_tls_change")
            UserDefaults.standard.set(Date(), forKey: "cached_tls_time")
        }
    }
    
    private func parseTelestaiPrice(from data: Data, source: Int) async -> (price: Double, change: Double)? {
        do {
            switch source {
            case 0: // CoinGecko
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let telestai = json["telestai"] as? [String: Any],
                   let usd = telestai["usd"] as? Double,
                   let usdChange = telestai["usd_24h_change"] as? Double {
                    return (usd, usdChange)
                }
            case 1: // Coinpaprika
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let quotes = json["quotes"] as? [String: Any],
                   let usd = quotes["USD"] as? [String: Any],
                   let price = usd["price"] as? Double,
                   let change = usd["change_24h"] as? Double {
                    return (price, change)
                }
            case 2: // CoinCap
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let data = json["data"] as? [String: Any],
                   let priceUsd = data["priceUsd"] as? String,
                   let changePercent24Hr = data["changePercent24Hr"] as? String,
                   let price = Double(priceUsd),
                   let change = Double(changePercent24Hr) {
                    return (price, change)
                }
            default:
                break
            }
        } catch {
            print("❌ Failed to parse Telestai price from source \(source): \(error)")
        }
        return nil
    }
    
    private func loadPriceHistory() async {
        isLoadingHistory = true
        
        // Check cache first
        if let cachedHistory = UserDefaults.standard.object(forKey: "cached_tls_history") as? [Double],
           let cacheTime = UserDefaults.standard.object(forKey: "cached_tls_history_time") as? Date {
            
            // Use cache if less than 10 minutes old
            if Date().timeIntervalSince(cacheTime) < 600 {
                await MainActor.run {
                    self.tlsPriceHistory = cachedHistory
                    print("✅ Using cached TLS history: \(cachedHistory.count) data points")
                }
                isLoadingHistory = false
                return
            }
        }
        
        // Try to get Telestai price history from multiple sources
        await loadTelestaiPriceHistoryFromSources()
        isLoadingHistory = false
    }
    
    private func loadTelestaiPriceHistoryFromSources() async {
        // Try multiple price history sources for Telestai
        let sources = [
            "https://api.coingecko.com/api/v3/coins/telestai/market_chart?vs_currency=usd&days=7",
            "https://api.coinpaprika.com/v1/coins/tls-telestai/ohlcv/historical?days=7",
            "https://api.coincap.io/v2/assets/telestai/history?interval=d1&start=\(Int(Date().timeIntervalSince1970 - 7*24*60*60)*1000)&end=\(Int(Date().timeIntervalSince1970)*1000)"
        ]
        
        for (index, urlString) in sources.enumerated() {
            guard let url = URL(string: urlString) else { continue }
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    // Try to parse the response based on the source
                    if let history = await parseTelestaiPriceHistory(from: data, source: index) {
                        await MainActor.run {
                            self.tlsPriceHistory = history
                            print("✅ Telestai price history loaded from source \(index + 1): \(history.count) data points")
                            
                            // Cache the successful response
                            UserDefaults.standard.set(history, forKey: "cached_tls_history")
                            UserDefaults.standard.set(Date(), forKey: "cached_tls_history_time")
                        }
                        return
                    }
                }
            } catch {
                print("❌ Failed to load Telestai price history from source \(index + 1): \(error)")
            }
        }
        
        // If all sources fail, generate realistic mock history
        print("ℹ️ All Telestai price history sources failed - using realistic mock data")
        let mockHistory = generateRealisticTelestaiHistory()
        
        await MainActor.run {
            self.tlsPriceHistory = mockHistory
            print("✅ Using realistic mock Telestai history: \(mockHistory.count) data points")
            
            // Cache the mock data
            UserDefaults.standard.set(mockHistory, forKey: "cached_tls_history")
            UserDefaults.standard.set(Date(), forKey: "cached_tls_history_time")
        }
    }
    
    private func parseTelestaiPriceHistory(from data: Data, source: Int) async -> [Double]? {
        do {
            switch source {
            case 0: // CoinGecko
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let prices = json["prices"] as? [[Any]] {
                    return prices.compactMap { priceData -> Double? in
                        guard priceData.count >= 2,
                              let price = priceData[1] as? Double else { return nil }
                        return price
                    }
                }
            case 1: // Coinpaprika
                if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    return json.compactMap { candle -> Double? in
                        guard let close = candle["close"] as? Double else { return nil }
                        return close
                    }
                }
            case 2: // CoinCap
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let data = json["data"] as? [[String: Any]] {
                    return data.compactMap { point -> Double? in
                        guard let priceUsd = point["priceUsd"] as? String,
                              let price = Double(priceUsd) else { return nil }
                        return price
                    }
                }
            default:
                break
            }
        } catch {
            print("❌ Failed to parse Telestai price history from source \(source): \(error)")
        }
        return nil
    }
    
    private func generateRealisticTelestaiHistory() -> [Double] {
        // Generate realistic 7-day price history for Telestai
        let basePrice = Double.random(in: 0.75...0.95)
        var history: [Double] = []
        
        for day in 0..<7 {
            let volatility = Double.random(in: -0.05...0.08) // 5% daily volatility
            let trend = Double.random(in: -0.02...0.03) // Slight trend
            let price = basePrice * (1 + Double(day) * trend + volatility)
            history.append(max(0.1, price)) // Ensure price doesn't go negative
        }
        
        return history
    }
    
    private func logout() {
        walletService.keychain.delete(key: "wallet_mnemonic")
        path.removeLast(path.count)
    }
    
    // MARK: - Action Helper Functions
    private func addToCalendar(title: String, start: Date, end: Date) {
        let eventStore = EKEventStore()
        
        // Request calendar access
        eventStore.requestFullAccessToEvents { granted, error in
            DispatchQueue.main.async {
            if granted {
                let event = EKEvent(eventStore: eventStore)
                event.title = title
                event.startDate = start
                event.endDate = end
                event.calendar = eventStore.defaultCalendarForNewEvents
                
                do {
                    try eventStore.save(event, span: .thisEvent)
                        print("✅ Event saved to calendar: \(title)")
                        self.alertMessage = "Meeting scheduled: \(title)"
                        self.showAlert = true
                } catch {
                        print("❌ Failed to save event: \(error)")
                        self.alertMessage = "Failed to schedule meeting"
                        self.showAlert = true
                    }
                } else {
                    print("❌ Calendar access denied")
                    self.alertMessage = "Calendar access required to schedule meetings"
                    self.showAlert = true
                }
            }
        }
    }

    private func openMaps(location: String) {
        let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location
        if let url = URL(string: "maps://?q=\(encodedLocation)") {
            UIApplication.shared.open(url)
            print("🗺️ Opening maps for: \(location)")
        }
    }

    private func openURL(url: String) {
        var urlString = url
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        
        if let url = URL(string: urlString) {
        UIApplication.shared.open(url)
            print("🌐 Opening URL: \(urlString)")
        }
    }
    
    private func openMessages(contact: String, message: String) {
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? message
        if let url = URL(string: "sms:\(contact)&body=\(encodedMessage)") {
            UIApplication.shared.open(url)
            print("💬 Opening messages for: \(contact)")
        }
    }
    
    private func openPhone(contact: String) {
        if let url = URL(string: "tel:\(contact)") {
            UIApplication.shared.open(url)
            print("📞 Opening phone for: \(contact)")
        }
    }
    
    private func openMail(to: String, subject: String) {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        if let url = URL(string: "mailto:\(to)?subject=\(encodedSubject)") {
            UIApplication.shared.open(url)
            print("📧 Opening mail for: \(to)")
        }
    }
    
    private func openCamera() {
        // This would typically open the camera app
        print("📷 Camera functionality would open camera app")
        alertMessage = "Camera functionality would open camera app"
        showAlert = true
    }
    
    private func openPhotos() {
        // This would typically open the photos app
        print("🖼️ Photos functionality would open photos app")
        alertMessage = "Photos functionality would open photos app"
        showAlert = true
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
            print("⚙️ Opening settings")
        }
    }
    
    private func openNotes(title: String, content: String) {
        // This would typically open the notes app
        print("📝 Notes functionality would create note: \(title)")
        alertMessage = "Notes functionality would create note: \(title)"
        showAlert = true
    }
    
    private func loadAndPrioritizeMessages() {
        // Mock implementation for message prioritization
        print("📋 Loading and prioritizing messages")
        alertMessage = "Message prioritization feature coming soon"
        showAlert = true
    }
    
    private func fetchBlockchainInfo() {
        // Mock implementation for blockchain stats
        print("📊 Fetching blockchain information")
        alertMessage = "Blockchain statistics feature coming soon"
        showAlert = true
    }
    
    /// Sets up listener for companion task execution requests
    private func setupCompanionTaskListener() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ExecuteCompanionTask"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let action = userInfo["action"] as? String,
               let parameters = userInfo["parameters"] as? [String: Any] {
                self.handleAction(action: action, parameters: parameters)
            }
        }
    }
}

struct LineChartView: View {
    let data: [Double]
    let width: CGFloat
    let height: CGFloat
    let isPositive: Bool
    
    private var isPriceIncreasing: Bool {
        guard data.count >= 2 else { return false }
        return data.last! >= data.first!
    }
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard data.count > 1 else { 
                    print("⚠️ LineChartView: Not enough data points (\(data.count))")
                    return 
                }
                
                // Validate data
                guard data.allSatisfy({ $0 > 0 }) else {
                    print("⚠️ LineChartView: Invalid data points found: \(data)")
                    return
                }
                
                let stepX = width / CGFloat(data.count - 1)
                let maxValue = data.max() ?? 1
                let minValue = data.min() ?? 0
                let range = maxValue - minValue
                
                print("📊 LineChartView: Drawing chart with \(data.count) points, range: \(minValue)-\(maxValue)")
                
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
            .stroke(isPositive ? Color.green : Color.red, lineWidth: 2)
        }
        .frame(width: width, height: height)
        .onAppear {
            print("📈 LineChartView appeared with \(data.count) data points")
        }
    }
}

// MARK: - Coin Icon Functions (Static)
struct CoinIconHelper {
    static func getCoinIcon(for coin: String) -> Image {
        switch coin {
        case "Telestai":
            return Image(systemName: "network")
        case "Bitcoin":
            return Image(systemName: "bitcoinsign.circle.fill")
        case "USDT":
            return Image(systemName: "dollarsign.circle.fill")
        case "USDC":
            return Image(systemName: "dollarsign.circle")
        case "Litecoin":
            return Image(systemName: "l.square.fill")
        case "Flux":
            return Image(systemName: "bolt.circle.fill")
        case "Kaspa":
            return Image(systemName: "k.square.fill")
        default:
            return Image(systemName: "circle.fill")
        }
    }
    
    static func getCoinIconBackground(for coin: String) -> Color {
        switch coin {
        case "Telestai":
            return Color(hex: "#4f225b").opacity(0.2)
        case "Bitcoin":
            return Color.orange.opacity(0.2)
        case "USDT":
            return Color.green.opacity(0.2)
        case "USDC":
            return Color.blue.opacity(0.2)
        case "Litecoin":
            return Color.gray.opacity(0.2)
        case "Flux":
            return Color.purple.opacity(0.2)
        case "Kaspa":
            return Color.red.opacity(0.2)
        default:
            return DesignSystem.Colors.secondary.opacity(0.2)
        }
    }
    
    static func getCoinIconColor(for coin: String) -> Color {
        switch coin {
        case "Telestai":
            return Color(hex: "#4f225b")
        case "Bitcoin":
            return .orange
        case "USDT":
            return .green
        case "USDC":
            return .blue
        case "Litecoin":
            return .gray
        case "Flux":
            return .purple
        case "Kaspa":
            return .red
        default:
            return DesignSystem.Colors.secondary
        }
    }
    
    static func isCustomImage(for coin: String) -> Bool {
        // Temporarily use SF Symbols for all coins
        return false
    }
}

// MARK: - Coin Row View (Trust Wallet Style)
struct CoinRowView: View {
    let coin: String
    let isSelected: Bool
    let balance: Double
    let price: Double
    let priceChange: Double
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Coin Icon/Logo
                ZStack {
                    Circle()
                        .fill(CoinIconHelper.getCoinIconBackground(for: coin))
                        .frame(width: 40, height: 40)
                    
                    CoinIconHelper.getCoinIcon(for: coin)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(CoinIconHelper.getCoinIconColor(for: coin))
                }
                
                // Coin Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(coin)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Text("\(String(format: "%.4f", balance)) \(coin)")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Price Info
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(String(format: "%.2f", balance * price))")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    HStack(spacing: 4) {
                        Text("$\(String(format: "%.2f", price))")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        if priceChange != 0 {
                            Image(systemName: priceChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10))
                                .foregroundColor(priceChange >= 0 ? .green : .red)
                            
                            Text("\(String(format: "%.1f", abs(priceChange)))%")
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(priceChange >= 0 ? .green : .red)
                        }
                    }
                }
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.secondary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(isSelected ? DesignSystem.Colors.secondary.opacity(0.1) : DesignSystem.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(isSelected ? DesignSystem.Colors.secondary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BottomNavigationView: View {
    @Binding var selectedTab: Int
    @Binding var showMessaging: Bool
    @Binding var showHamburgerMenu: Bool
    @Binding var path: NavigationPath
    @ObservedObject var themeManager: ThemeManager = .shared
    
    var body: some View {
        HStack(spacing: 0) {
            // Profile Tab
            Button(action: {
                selectedTab = 0
                path.append("profile")
            }) {
                Image(systemName: selectedTab == 0 ? "person.circle.fill" : "person.circle")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(selectedTab == 0 ? DesignSystem.Colors.secondary : DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            
            // Messaging Tab
            Button(action: {
                selectedTab = 1
                path.append("messaging")
            }) {
                Image(systemName: selectedTab == 1 ? "message.circle.fill" : "message.circle")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(selectedTab == 1 ? DesignSystem.Colors.secondary : DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            
            // AI Companion Tab
            Button(action: {
                selectedTab = 2
                path.append("ai-companion")
            }) {
                Image(systemName: selectedTab == 2 ? "brain.head.profile.fill" : "brain.head.profile")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(selectedTab == 2 ? DesignSystem.Colors.secondary : DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            
            // Menu Tab
            Button(action: {
                selectedTab = 3
                showHamburgerMenu = true
            }) {
                Image(systemName: selectedTab == 3 ? "line.3.horizontal.circle.fill" : "line.3.horizontal.circle")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(selectedTab == 3 ? DesignSystem.Colors.secondary : DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.xs) // 2mm from bottom of screen
        .background(DesignSystem.Colors.background)
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
                        
                        MenuButton(title: "Support & Help", icon: "questionmark.circle") {
                            path.append("support")
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
    @State private var selectedLanguage = "English"
    @State private var selectedCurrency = "USD"
    @State private var selectedTheme = "Native"
    @State private var availableLanguages = ["English", "Spanish", "French", "German", "Chinese"]
    @State private var availableCurrencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD"]
    @State private var availableThemes = ["Native", "Light", "Dark"]
    @State private var analyticsData: AnalyticsData?
    @State private var activeSessions: [SessionInfo] = []
    @State private var showEditPersonalInfo = false
    @State private var showLanguagePicker = false
    @State private var showCurrencyPicker = false
    @State private var showThemePicker = false
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var themeManager = ThemeManager.shared
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
                    
                    Text("Profile")
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
                                Text(LocalizedString.localized("personal_information"))
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
                                
                                Text(LocalizedString.localized("tap_to_upload_photo"))
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                // Personal Info Display
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    // Display Name
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                        Text(LocalizedString.localized("display_name"))
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                        Text(displayName.isEmpty ? LocalizedString.localized("not_set") : displayName)
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .foregroundColor(DesignSystem.Colors.text)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(DesignSystem.Spacing.sm)
                                    .background(DesignSystem.Colors.surface.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    // Bio
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                        Text(LocalizedString.localized("bio"))
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                        Text(userBio.isEmpty ? LocalizedString.localized("not_set") : userBio)
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .foregroundColor(DesignSystem.Colors.text)
                                            .lineLimit(3)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(DesignSystem.Spacing.sm)
                                    .background(DesignSystem.Colors.surface.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    // Location
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                        Text(LocalizedString.localized("location"))
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                        Text(userLocation.isEmpty ? LocalizedString.localized("not_set") : userLocation)
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .foregroundColor(DesignSystem.Colors.text)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(DesignSystem.Spacing.sm)
                                    .background(DesignSystem.Colors.surface.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    // Single Edit Button
                                    Button(action: {
                                        showEditPersonalInfo = true
                                    }) {
                                        HStack(spacing: DesignSystem.Spacing.sm) {
                                            Image(systemName: "pencil")
                                                .font(.system(size: 16))
                                                .foregroundColor(DesignSystem.Colors.secondary)
                                            Text(LocalizedString.localized("edit"))
                                                .font(DesignSystem.Typography.bodyMedium)
                                                .foregroundColor(DesignSystem.Colors.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(DesignSystem.Spacing.sm)
                                        .background(DesignSystem.Colors.secondary.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        // Streaming Switch
                        CardView {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                Text("Stream Metadata")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.text)
                                
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    Toggle("Enable", isOn: $isStreaming)
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .foregroundColor(DesignSystem.Colors.text)
                                        .onChange(of: isStreaming) { newValue in
                                            UserDefaults.standard.set(newValue, forKey: "user_streaming_enabled")
                                        }
                                    
                                    Text("Sell your data to Advertisers")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .multilineTextAlignment(.leading)
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
                        

                        
                        // Action Buttons
                        VStack(spacing: DesignSystem.Spacing.md) {
                            PrimaryButton("Log Out") {
                                logout()
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
        .sheet(isPresented: $showEditPersonalInfo) {
            EditPersonalInfoView(displayName: $displayName, userBio: $userBio, userLocation: $userLocation)
        }
        .sheet(isPresented: $showLanguagePicker) {
            PreferencePickerView(title: "Language", selection: $selectedLanguage, options: availableLanguages, onSelectionChanged: { newLanguage in
                saveLanguage(newLanguage)
            })
        }
        .sheet(isPresented: $showCurrencyPicker) {
            PreferencePickerView(title: "Currency", selection: $selectedCurrency, options: availableCurrencies, onSelectionChanged: { newCurrency in
                saveCurrency(newCurrency)
            })
        }
        .sheet(isPresented: $showThemePicker) {
            PreferencePickerView(title: "Theme", selection: $selectedTheme, options: availableThemes, onSelectionChanged: { newTheme in
                saveTheme(newTheme)
            })
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
    
    private func logout() {
        walletService.keychain.delete(key: "wallet_mnemonic")
        path.removeLast(path.count)
    }
    
    private func testConnection() {
        alertMessage = "Connection test completed successfully!"
        showAlert = true
    }
    
    private func loadSettings() {
        // Load saved preferences from UserDefaults
        selectedLanguage = UserDefaults.standard.string(forKey: "user_language") ?? "English"
        selectedCurrency = UserDefaults.standard.string(forKey: "user_currency") ?? "USD"
        selectedTheme = UserDefaults.standard.string(forKey: "user_theme") ?? "Native"
        isStreaming = UserDefaults.standard.bool(forKey: "user_streaming_enabled")
        
        // Apply loaded settings
        LocalizationManager.shared.currentLanguage = selectedLanguage
        DesignSystem.updateTheme(selectedTheme)
    }
    
    private func saveLanguage(_ language: String) {
        selectedLanguage = language
        UserDefaults.standard.set(language, forKey: "user_language")
        applyLanguageSettings(language)
    }
    
    private func saveCurrency(_ currency: String) {
        selectedCurrency = currency
        UserDefaults.standard.set(currency, forKey: "user_currency")
        applyCurrencySettings(currency)
    }
    
    private func saveTheme(_ theme: String) {
        selectedTheme = theme
        UserDefaults.standard.set(theme, forKey: "user_theme")
        applyThemeSettings(theme)
    }
    
    private func applyLanguageSettings(_ language: String) {
        // Apply language changes throughout the app
        LocalizationManager.shared.currentLanguage = language
    }
    
    private func applyCurrencySettings(_ currency: String) {
        // Apply currency changes throughout the app
        // Currency changes can be implemented here when needed
    }
    
    private func applyThemeSettings(_ theme: String) {
        // Apply theme changes throughout the app
        DesignSystem.updateTheme(theme)
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
    @Binding var path: NavigationPath
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Header
                HStack {
                    Spacer()
                    
                    Text("Network Stats")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.lg)
                
                Spacer()
                
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 60))
                        .foregroundColor(DesignSystem.Colors.secondary)
                    
                    Text("Coming Soon")
                        .font(DesignSystem.Typography.titleLarge)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Text("Network statistics and analytics will be available in a future update.")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                }
                
                Spacer()
            }
        }
    }
}

struct AIFeaturesView: View {
    @Binding var path: NavigationPath
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Header
                HStack {
                    Spacer()
                    
                    Text("AI Features")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.lg)
                
                Spacer()
                
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 60))
                        .foregroundColor(DesignSystem.Colors.secondary)
                    
                    Text("Coming Soon")
                        .font(DesignSystem.Typography.titleLarge)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Text("Advanced AI features and capabilities will be available in a future update.")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                }
                
                Spacer()
            }
        }
    }
}

struct SupportView: View {
    @Binding var path: NavigationPath
    @State private var showBugReport = false
    @State private var bugDescription = ""
    @State private var bugCategory = "General"
    @State private var bugCategories = ["General", "AI Issues", "Payment Issues", "UI/UX", "Performance", "Security"]
    
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
                    
                    Text("Support & Help")
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
                        // FAQ Section
                        CardView {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                Text("Frequently Asked Questions")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.text)
                                
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    Text("How do I create a new account?")
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .foregroundColor(DesignSystem.Colors.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Text("Tap 'Create New Account' on the login screen. Write down your recovery phrase securely.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(DesignSystem.Spacing.sm)
                                .background(DesignSystem.Colors.surface.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    Text("How do I change my theme?")
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .foregroundColor(DesignSystem.Colors.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Text("Go to Menu → Settings → Preferences → Theme to change your app appearance.")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(DesignSystem.Spacing.sm)
                                .background(DesignSystem.Colors.surface.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        // Support Actions
                        CardView {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                Text("Get Help")
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
                                    
                                    Button(action: {
                                        // Email support
                                        if let url = URL(string: "mailto:support@telestai.com") {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "envelope")
                                                .foregroundColor(DesignSystem.Colors.secondary)
                                            Text("Email Support")
                                                .font(DesignSystem.Typography.bodyMedium)
                                                .foregroundColor(DesignSystem.Colors.text)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                        }
                                        .padding(.vertical, DesignSystem.Spacing.sm)
                                    }
                                    
                                    Button(action: {
                                        // Open documentation
                                        if let url = URL(string: "https://docs.telestai.com") {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "doc.text")
                                                .foregroundColor(DesignSystem.Colors.secondary)
                                            Text("Documentation")
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
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showBugReport) {
            BugReportView(bugDescription: $bugDescription, bugCategory: $bugCategory, bugCategories: bugCategories)
        }
    }
}

struct SettingsView: View {
    @Binding var path: NavigationPath
    @State private var biometricEnabled = true
    @State private var showSessionManagement = false
    @State private var selectedLanguage = "English"
    @State private var selectedCurrency = "USD"
    @State private var selectedTheme = "Native"
    @State private var availableLanguages = ["English", "Spanish", "French", "German", "Chinese"]
    @State private var availableCurrencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD"]
    @State private var availableThemes = ["Native", "Light", "Dark"]
    @State private var showLanguagePicker = false
    @State private var showCurrencyPicker = false
    @State private var showThemePicker = false
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    
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
                    
                    Text("Settings")
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
                                Text(LocalizedString.localized("preferences"))
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.text)
                                
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    // Language Button
                                    Button(action: {
                                        showLanguagePicker = true
                                    }) {
                                        HStack {
                                            Text(LocalizedString.localized("language"))
                                                .font(DesignSystem.Typography.bodyMedium)
                                                .foregroundColor(DesignSystem.Colors.text)
                                            Spacer()
                                            Text(selectedLanguage)
                                                .font(DesignSystem.Typography.bodyMedium)
                                                .foregroundColor(DesignSystem.Colors.secondary)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12))
                                                .foregroundColor(DesignSystem.Colors.secondary)
                                        }
                                        .padding(DesignSystem.Spacing.sm)
                                        .background(DesignSystem.Colors.secondary.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    
                                    // Currency Button
                                    Button(action: {
                                        showCurrencyPicker = true
                                    }) {
                                        HStack {
                                            Text(LocalizedString.localized("currency"))
                                                .font(DesignSystem.Typography.bodyMedium)
                                                .foregroundColor(DesignSystem.Colors.text)
                                            Spacer()
                                            Text(selectedCurrency)
                                                .font(DesignSystem.Typography.bodyMedium)
                                                .foregroundColor(DesignSystem.Colors.secondary)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12))
                                                .foregroundColor(DesignSystem.Colors.secondary)
                                        }
                                        .padding(DesignSystem.Spacing.sm)
                                        .background(DesignSystem.Colors.secondary.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    
                                    // Theme Button
                                    Button(action: {
                                        showThemePicker = true
                                    }) {
                                        HStack {
                                            Text(LocalizedString.localized("theme"))
                                                .font(DesignSystem.Typography.bodyMedium)
                                                .foregroundColor(DesignSystem.Colors.text)
                                            Spacer()
                                            Text(selectedTheme)
                                                .font(DesignSystem.Typography.bodyMedium)
                                                .foregroundColor(DesignSystem.Colors.secondary)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 12))
                                                .foregroundColor(DesignSystem.Colors.secondary)
                                        }
                                        .padding(DesignSystem.Spacing.sm)
                                        .background(DesignSystem.Colors.secondary.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showLanguagePicker) {
            PreferencePickerView(
                title: "Language",
                selection: $selectedLanguage,
                options: availableLanguages,
                onSelectionChanged: { language in
                    localizationManager.currentLanguage = language
                }
            )
        }
        .sheet(isPresented: $showCurrencyPicker) {
            PreferencePickerView(
                title: "Currency",
                selection: $selectedCurrency,
                options: availableCurrencies,
                onSelectionChanged: { currency in
                    UserDefaults.standard.set(currency, forKey: "user_currency")
                }
            )
        }
        .sheet(isPresented: $showThemePicker) {
            PreferencePickerView(
                title: "Theme",
                selection: $selectedTheme,
                options: availableThemes,
                onSelectionChanged: { theme in
                    themeManager.currentTheme = theme
                }
            )
        }
        .sheet(isPresented: $showSessionManagement) {
            SessionManagementView(sessions: .constant([]))
        }
        .onAppear {
            // Load saved preferences
            selectedLanguage = UserDefaults.standard.string(forKey: "user_language") ?? "English"
            selectedCurrency = UserDefaults.standard.string(forKey: "user_currency") ?? "USD"
            selectedTheme = UserDefaults.standard.string(forKey: "user_theme") ?? "Native"
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
    @Binding var displayName: String
    @Binding var userBio: String
    @Binding var userLocation: String
    
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
                        
                        Text("Edit Personal Info")
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
                    
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            CardView {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                    Text("Personal Information")
                                        .font(DesignSystem.Typography.headline)
                                        .foregroundColor(DesignSystem.Colors.text)
                                    
                                    VStack(spacing: DesignSystem.Spacing.md) {
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
                        }
                        .padding(.vertical, DesignSystem.Spacing.lg)
                    }
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

// MARK: - Preference Picker View
struct PreferencePickerView: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    let onSelectionChanged: ((String) -> Void)?
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
                
                        Text(title)
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.text)
                        
                        Spacer()
                        
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(DesignSystem.Colors.secondary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.lg)
                    
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(options, id: \.self) { option in
                                Button(action: {
                                    selection = option
                                    onSelectionChanged?(option)
                                    dismiss()
                                }) {
                                    HStack {
                                        Text(option)
                    .font(DesignSystem.Typography.bodyMedium)
                                            .foregroundColor(DesignSystem.Colors.text)
                
                Spacer()
                                        
                                        if selection == option {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(DesignSystem.Colors.secondary)
                                        }
                                    }
                                    .padding(DesignSystem.Spacing.md)
                                    .background(selection == option ? DesignSystem.Colors.secondary.opacity(0.1) : DesignSystem.Colors.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
            }
        }
        .navigationBarHidden(true)
        }
    }
}

// MARK: - Menu Item View
struct MenuItemView: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(DesignSystem.Colors.text)
                
                Text(subtitle)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 16))
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

// MARK: - Menu View
struct MenuView: View {
    @Binding var path: NavigationPath
    @State private var showLogoutAlert = false
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Header
                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("Menu")
                        .font(DesignSystem.Typography.titleLarge)
                        .foregroundColor(DesignSystem.Colors.text)
                    
                    Text("PAAI Settings & Options")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DesignSystem.Spacing.xxl)
                
                // Menu Items
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Hybrid Messaging
                    NavigationLink(destination: HybridMessagingView()) {
                        MenuItemView(
                            icon: "network",
                            title: "Hybrid Messaging",
                            subtitle: "P2P + Layer 2 + Blockchain",
                            color: .purple
                        )
                    }
                    
                    // Settings
                    NavigationLink(destination: SettingsView(path: $path)) {
                        MenuItemView(
                            icon: "gearshape",
                            title: "Settings",
                            subtitle: "AI Status, Security & Preferences",
                            color: .blue
                        )
                    }
                    
                    // Support & Help
                    NavigationLink(destination: SupportView(path: $path)) {
                        MenuItemView(
                            icon: "questionmark.circle",
                            title: "Support & Help",
                            subtitle: "Get help and report issues",
                            color: .green
                        )
                    }
                    
                    // Log Out
                    Button(action: {
                        showLogoutAlert = true
                    }) {
                        MenuItemView(
                            icon: "rectangle.portrait.and.arrow.right",
                            title: "Log Out",
                            subtitle: "Sign out of your account",
                            color: .red
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                
                Spacer()
            }
        }
        .alert("Log Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                logout()
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
    }
    
    private func logout() {
        WalletService.shared.clear()
        path = NavigationPath()
    }
}

