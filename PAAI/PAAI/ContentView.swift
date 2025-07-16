import SwiftUI
import EventKit
import MapKit
import Combine

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

struct ContentView: View {
    @State private var address = ""
    @State private var mnemonic = ""
    @State private var isCheckingLogin = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var path = NavigationPath()
    @StateObject private var assistantService = AssistantService.shared

    private let walletService = WalletService.shared

    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                Spacer()
                VStack(spacing: 20) {
                    TextField("Enter Wallet Address", text: $address)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.custom("AzoSansRegular", size: 16))
                        .frame(height: 40)
                        .disableInputAccessoryView()
                        .padding(.horizontal)
                    SecureField("Enter Mnemonic", text: $mnemonic)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.custom("AzoSansRegular", size: 16))
                        .frame(height: 40)
                        .disableInputAccessoryView()
                        .padding(.horizontal)
                    Button("Sign In") {
                        guard !isCheckingLogin else { return }
                        isCheckingLogin = true
                        print("Attempting sign-in with address: \(address), mnemonic: \(mnemonic)")
                        if address.isEmpty || mnemonic.isEmpty {
                            errorMessage = "Both address and mnemonic are required"
                            showError = true
                            isCheckingLogin = false
                            return
                        }
                        walletService.importMnemonic(mnemonic) { success, derivedAddress in
                            print("Import result: success=\(success), derivedAddress=\(derivedAddress ?? "nil")")
                            if success, derivedAddress == address {
                                print("Login successful, navigating to home")
                                path.append("home")
                            } else {
                                errorMessage = "Invalid address or mnemonic"
                                showError = true
                            }
                            isCheckingLogin = false
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "#b37fc6"))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                    .font(.custom("AbadiMTProBold", size: 16))
                    .padding(.horizontal)
                    .disabled(isCheckingLogin)
                    NavigationLink("Create New Account", value: "create")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "#d6b8db"))
                        .foregroundColor(Color(hex: "#803a99"))
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                        .font(.custom("AbadiMTProBold", size: 16))
                        .padding(.horizontal)
                }
                Spacer()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .background(Color(hex: "#4f225b"))
            .alert(isPresented: $showError) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
            .navigationDestination(for: String.self) { value in
                switch value {
                case "home":
                    HomeView(path: $path, assistantService: assistantService)
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

    private func checkAutoLogin() {
        guard !isCheckingLogin else { return }
        isCheckingLogin = true
        if let savedAddress = walletService.loadAddress(),
           let savedMnemonic = walletService.keychain.read(key: "wallet_mnemonic") {
            print("Auto-login: address=\(savedAddress), mnemonic=\(savedMnemonic)")
            walletService.importMnemonic(savedMnemonic) { success, derivedAddress in
                print("Auto-login import: success=\(success), derivedAddress=\(derivedAddress ?? "nil")")
                if success, derivedAddress == savedAddress {
                    print("Auto-login successful")
                    path.append("home")
                }
                isCheckingLogin = false
            }
        } else {
            print("No auto-login credentials found")
            isCheckingLogin = false
        }
    }
}

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

struct CreateAccountView: View {
    @Binding var path: NavigationPath
    @State private var mnemonic = ""
    @State private var hasWrittenDown = false
    @State private var showMnemonic = false
    @State private var showConfirm = false
    private let walletService = WalletService.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create Account")
                    .font(.custom("AbadiMTProBold", size: 28))
                    .foregroundColor(Color(hex: "#803a99"))
                    .padding(.top, 40)
                HStack {
                    Text(showMnemonic ? mnemonic : String(repeating: "•", count: 32))
                        .font(.custom("AzoSansRegular", size: 14))
                        .padding()
                    Button(action: { showMnemonic.toggle() }) {
                        Image(systemName: showMnemonic ? "eye.slash" : "eye")
                            .foregroundColor(.white)
                    }
                    Button(action: {
                        UIPasteboard.general.string = mnemonic
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                .background(Color(hex: "#4f225b").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                Toggle("I have written this down", isOn: $hasWrittenDown)
                    .font(.custom("AzoSansRegular", size: 16))
                    .padding(.horizontal)
                Button("Proceed") {
                    showConfirm = true
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(hasWrittenDown ? Color(hex: "#b37fc6") : Color(hex: "#4f225b").opacity(0.5))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .font(.custom("AbadiMTProBold", size: 16))
                .padding(.horizontal)
                .disabled(!hasWrittenDown)
                Spacer()
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { path = NavigationPath() }
                        .font(.custom("AzoSansRegular", size: 16))
                        .foregroundColor(Color(hex: "#803a99"))
                }
            }
            .background(Color(hex: "#4f225b"))
            .alert(isPresented: $showConfirm) {
                Alert(
                    title: Text("Confirm"),
                    message: Text("Are you sure you want to proceed?"),
                    primaryButton: .default(Text("Yes")) {
                        walletService.importMnemonic(mnemonic) { success, _ in
                            if success {
                                path = NavigationPath() // Reset to main screen
                            }
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .onAppear {
                mnemonic = walletService.generateMnemonic()
            }
        }
    }
}

struct HomeView: View {
    @Binding var path: NavigationPath
    @ObservedObject var assistantService: AssistantService
    @State private var commandInput = ""
    @State private var isSubscribed = false
    @State private var isInitializing = false
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
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
                    if isInitializing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#803a99")))
                    } else if !isSubscribed {
                        VStack(spacing: 20) {
                            Text("Subscription Required")
                                .font(.custom("AbadiMTProBold", size: 24))
                                .foregroundColor(Color(hex: "#803a99"))
                            Button("Pay Now") {
                                isSubscribed = walletService.sendPayment()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(hex: "#b37fc6"))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                            .font(.custom("AbadiMTProBold", size: 16))
                            .padding(.horizontal)
                        }
                    } else {
                        Spacer()
                        HStack {
                            Spacer()
                            TextField("How may I help you?", text: $commandInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.custom("AzoSansRegular", size: 16))
                                .frame(height: 40)
                                .disableInputAccessoryView()
                                .padding(.horizontal)
                            Button(action: {
                                handleCommand()
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color(hex: "#b37fc6"))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        if let chain = chain, let blockHeight = blockHeight,
                           let lastBlockHash = lastBlockHash, let networkHashrate = networkHashrate {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Chain: \(chain)")
                                    .font(.custom("AzoSansRegular", size: 14))
                                Text("Block Height: \(blockHeight)")
                                    .font(.custom("AzoSansRegular", size: 14))
                                Text("Last Block Hash: \(lastBlockHash)")
                                    .font(.custom("AzoSansRegular", size: 14))
                                Text("Network Hashrate: \(String(format: "%.2f", networkHashrate)) GH/s")
                                    .font(.custom("AzoSansRegular", size: 14))
                            }
                            .padding()
                            .background(Color(hex: "#4f225b").opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal)
                        }
                        Spacer()
                    }
                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
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
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color(hex: "#803a99"))
                            .clipShape(Circle())
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        path.append("userPortal")
                    }) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(Color(hex: "#803a99"))
                    }
                }
            }
            .background(Color(hex: "#4f225b"))
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Success"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func initialize() {
        guard !isInitializing else { return }
        isInitializing = true
        walletService.initialize {
            isSubscribed = walletService.checkSubscription()
            fetchBlockchainInfo()
            loadAndPrioritizeMessages()
            isInitializing = false
        }
    }

    private func fetchBlockchainInfo() {
        guard let statsURL = URL(string: "https://telestai.cryptoscope.io/api/stats/") else {
            print("Invalid stats API URL")
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
                print("Stats decode error: \(String(data: data ?? Data(), encoding: .utf8) ?? "No data")")
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
            alertMessage = "Subscription required or empty input"
            showAlert = true
            assistantService.speak(alertMessage)
            return
        }
        let input = "Parse this command: \"\(commandInput)\". Identify the action (e.g., \"add meeting\", \"schedule meeting\", \"open maps\", \"open safari\", \"prioritize messages\", \"tell main stats\", \"sign message\", \"open user portal\", \"toggle stream\") and return only a JSON object with \"action\" (string), and relevant parameters (e.g., \"title\", \"start\", \"end\" for meetings, \"location\" for maps, \"url\" for safari, \"message\" for sign message). Use UTC timezone and assume today is 2025-07-15."
        print("Sending Grok API request: \(input)")
        networkService.getGrokResponse(input: input) { result in
            print("Grok API result: \(result)")
            switch result {
            case .success(let response):
                assistantService.speak(response)
                if let data = response.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let action = json["action"] as? String {
                    print("Parsed action: \(action), json: \(json)")
                    switch action {
                    case "add meeting", "schedule meeting":
                        if let title = json["title"] as? String,
                           let start = json["start"] as? String,
                           let end = json["end"] as? String,
                           let startDate = ISO8601DateFormatter().date(from: start),
                           let endDate = ISO8601DateFormatter().date(from: end) {
                            addToCalendar(title: title, start: startDate, end: endDate)
                        } else {
                            assistantService.speak("Invalid meeting details")
                            alertMessage = "Invalid meeting details"
                            showAlert = true
                        }
                    case "open maps":
                        if let location = json["location"] as? String {
                            openMaps(location: location)
                        }
                    case "open safari":
                        if let url = json["url"] as? String {
                            openURL(url: url)
                        }
                    case "prioritize messages":
                        loadAndPrioritizeMessages()
                        path.append("prioritization")
                    case "tell main stats":
                        fetchBlockchainInfo()
                        path.append("stats")
                    case "sign message":
                        if let message = json["message"] as? String,
                           let signature = walletService.signMessage(message) {
                            let response = "Signed: \(message) (Signature: \(signature))"
                            assistantService.speak(response)
                            alertMessage = response
                            showAlert = true
                        } else {
                            assistantService.speak("Failed to sign message")
                            alertMessage = "Failed to sign message"
                            showAlert = true
                        }
                    case "toggle stream":
                        let newValue = !assistantService.isStreaming
                        assistantService.toggleStreaming(newValue) { success in
                            let response = "Data streaming \(success ? newValue ? "enabled" : "disabled" : "failed")"
                            assistantService.speak(response)
                            alertMessage = response
                            showAlert = true
                        }
                    default:
                        assistantService.speak("Unknown action")
                        alertMessage = "Unknown action"
                        showAlert = true
                    }
                } else {
                    assistantService.speak("Invalid response format")
                    alertMessage = "Invalid response format"
                    showAlert = true
                }
            case .failure:
                print("Grok API failed, using mock response")
                if commandInput.lowercased().contains("add meeting") || commandInput.lowercased().contains("schedule meeting") {
                    let title = commandInput.components(separatedBy: " ").dropFirst(2).joined(separator: " ").capitalized
                    let startDate = ISO8601DateFormatter().date(from: "2025-07-16T15:00:00Z") ?? Date()
                    let endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? Date()
                    addToCalendar(title: title, start: startDate, end: endDate)
                } else if commandInput.contains("open maps") {
                    openMaps(location: "Sydney")
                } else if commandInput.contains("open safari") {
                    openURL(url: "https://www.example.com")
                } else if commandInput.contains("prioritize messages") {
                    loadAndPrioritizeMessages()
                    path.append("prioritization")
                } else if commandInput.contains("tell main stats") {
                    fetchBlockchainInfo()
                    path.append("stats")
                } else if commandInput.contains("sign message") {
                    if let signature = walletService.signMessage("Hello") {
                        let response = "Signed: Hello (Signature: \(signature))"
                        assistantService.speak(response)
                        alertMessage = response
                        showAlert = true
                    } else {
                        assistantService.speak("Failed to sign message")
                        alertMessage = "Failed to sign message"
                        showAlert = true
                    }
                } else if commandInput.contains("toggle stream") {
                    let newValue = !assistantService.isStreaming
                    assistantService.toggleStreaming(newValue) { success in
                        let response = "Data streaming \(success ? newValue ? "enabled" : "disabled" : "failed")"
                        assistantService.speak(response)
                        alertMessage = response
                        showAlert = true
                    }
                } else {
                    assistantService.speak("Error contacting Grok API")
                    alertMessage = "Error contacting Grok API"
                    showAlert = true
                }
            }
            commandInput = ""
        }
    }

    private func addToCalendar(title: String, start: Date, end: Date) {
        let store = EKEventStore()
        store.requestFullAccessToEvents { granted, error in
            if let error = error {
                print("Calendar access error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.assistantService.speak("Calendar access error")
                    self.alertMessage = "Calendar access error"
                    self.showAlert = true
                }
                return
            }
            guard granted else {
                print("Calendar access denied")
                DispatchQueue.main.async {
                    self.assistantService.speak("Please allow calendar access in Settings")
                    self.alertMessage = "Please allow calendar access in Settings"
                    self.showAlert = true
                }
                return
            }
            let event = EKEvent(eventStore: store)
            event.title = title
            event.startDate = start
            event.endDate = end
            event.calendar = store.defaultCalendarForNewEvents
            do {
                try store.save(event, span: .thisEvent)
                DispatchQueue.main.async {
                    self.assistantService.speak("Event added: \(title)")
                    self.alertMessage = "Event added: \(title)"
                    self.showAlert = true
                }
            } catch {
                print("Calendar save error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.assistantService.speak("Failed to add event")
                    self.alertMessage = "Failed to add event"
                    self.showAlert = true
                }
            }
        }
    }

    private func openMaps(location: String) {
        let url = "http://maps.apple.com/?q=\(location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let mapURL = URL(string: url) {
            UIApplication.shared.open(mapURL)
        }
    }

    private func openURL(url: String) {
        if let validURL = URL(string: url) {
            UIApplication.shared.open(validURL)
        }
    }
}

struct PrioritizationView: View {
    let messages: [Message]
    @Binding var path: NavigationPath
    @Environment(\.dismiss) var dismiss
    @State private var showPreview = false
    @State private var selectedMessage: Message?

    var body: some View {
        NavigationView {
            List(messages) { msg in
                HStack {
                    Circle()
                        .frame(width: 10, height: 10)
                        .foregroundColor(msg.viewed ? Color(hex: "#b37fc6").opacity(0.3) : Color(hex: "#b37fc6"))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(msg.contact): \(msg.content)")
                            .font(.custom("AzoSansRegular", size: 16))
                        Text("Priority: \(msg.priority), Time: \(msg.timestamp)")
                            .font(.custom("AzoSansRegular", size: 12))
                            .foregroundColor(Color(hex: "#803a99"))
                    }
                }
                .padding(.vertical, 5)
                .onTapGesture {
                    selectedMessage = msg
                    showPreview = true
                }
            }
            .navigationTitle("Prioritized Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                        .font(.custom("AzoSansRegular", size: 16))
                        .foregroundColor(Color(hex: "#803a99"))
                }
            }
            .alert(isPresented: $showPreview) {
                Alert(
                    title: Text("Message Preview"),
                    message: Text("""
                        From: \(selectedMessage?.contact ?? "")
                        Message: \(selectedMessage?.content ?? "")
                        Time: \(selectedMessage?.timestamp ?? "")
                        Priority: \(selectedMessage?.priority ?? 0)
                        \(selectedMessage?.viewed == true ? "ACTIONED" : "")
                        """),
                    primaryButton: .default(Text("Action in App")) {
                        if let msg = selectedMessage, !msg.viewed {
                            let updatedMessages = messages.map { m in
                                Message(id: m.id, contact: m.contact, content: m.content, timestamp: m.timestamp, viewed: m.id == msg.id ? true : m.viewed, priority: m.priority)
                            }
                            if let messagesData = try? JSONSerialization.data(withJSONObject: updatedMessages.map { [
                                "id": $0.id,
                                "contact": $0.contact,
                                "content": $0.content,
                                "timestamp": $0.timestamp,
                                "viewed": $0.viewed,
                                "priority": $0.priority
                            ]}) {
                                _ = WalletService.shared.keychain.save(key: "prioritized_messages", value: String(data: messagesData, encoding: .utf8)!)
                            }
                            if let url = URL(string: "mailto:\(msg.contact)") {
                                UIApplication.shared.open(url)
                            }
                        }
                    },
                    secondaryButton: .cancel(Text("Dismiss"))
                )
            }
            .background(Color(hex: "#4f225b"))
        }
    }
}

struct StatsView: View {
    @Binding var path: NavigationPath
    @State private var chain: String?
    @State private var blockHeight: Int?
    @State private var lastBlockHash: String?
    @State private var networkHashrate: Double?

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Blockchain Stats")
                    .font(.custom("AbadiMTProBold", size: 28))
                    .foregroundColor(Color(hex: "#803a99"))
                    .padding(.top, 40)
                if let chain = chain, let blockHeight = blockHeight,
                   let lastBlockHash = lastBlockHash, let networkHashrate = networkHashrate {
                    Text("Chain: \(chain)")
                        .font(.custom("AzoSansRegular", size: 16))
                    Text("Block Height: \(blockHeight)")
                        .font(.custom("AzoSansRegular", size: 16))
                    Text("Last Block Hash: \(lastBlockHash)")
                        .font(.custom("AzoSansRegular", size: 16))
                    Text("Network Hashrate: \(String(format: "%.2f", networkHashrate)) GH/s")
                        .font(.custom("AzoSansRegular", size: 16))
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#803a99")))
                }
            }
            .padding(.horizontal)
            .navigationTitle("Blockchain Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { path.removeLast() }
                        .font(.custom("AzoSansRegular", size: 16))
                        .foregroundColor(Color(hex: "#803a99"))
                }
            }
            .background(Color(hex: "#4f225b"))
            .onAppear {
                fetchBlockchainInfo()
            }
        }
    }

    private func fetchBlockchainInfo() {
        guard let statsURL = URL(string: "https://telestai.cryptoscope.io/api/stats/") else {
            print("Invalid stats API URL")
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
                print("Stats decode error: \(String(data: data ?? Data(), encoding: .utf8) ?? "No data")")
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
}

struct UserPortalView: View {
    @Binding var path: NavigationPath
    @State private var email = ""
    @State private var dob = ""
    @State private var address: String?
    @State private var mnemonic: String?
    @State private var showMnemonic = false
    @State private var showMnemonicAlert = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isStreaming = false
    private let walletService = WalletService.shared
    private let assistantService = AssistantService.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(Color(hex: "#803a99"))
                    .padding(.top, 40)
                TextField("Email", text: $email)
                    .disabled(true)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.custom("AzoSansRegular", size: 16))
                    .frame(height: 40)
                    .disableInputAccessoryView()
                    .padding(.horizontal)
                TextField("Date of Birth (YYYY-MM-DD)", text: $dob)
                    .disabled(true)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.custom("AzoSansRegular", size: 16))
                    .frame(height: 40)
                    .disableInputAccessoryView()
                    .padding(.horizontal)
                if let address = address {
                    HStack {
                        Text("Address: \(shortenAddress(address))")
                            .font(.custom("AzoSansRegular", size: 14))
                        Button(action: {
                            UIPasteboard.general.string = address
                            alertMessage = "Address copied"
                            showAlert = true
                        }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    .background(Color(hex: "#4f225b").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }
                if showMnemonic, let mnemonic = mnemonic {
                    HStack {
                        Text(mnemonic)
                            .font(.custom("AzoSansRegular", size: 14))
                        Button(action: {
                            UIPasteboard.general.string = mnemonic
                            alertMessage = "Mnemonic copied"
                            showAlert = true
                        }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    .background(Color(hex: "#4f225b").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }
                Button("Reveal Mnemonic") {
                    showMnemonicAlert = true
                    if let mnemonic = walletService.keychain.read(key: "wallet_mnemonic") {
                        self.mnemonic = mnemonic
                        showMnemonic = true
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#b37fc6"))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .font(.custom("AbadiMTProBold", size: 16))
                .padding(.horizontal)
                Button("Save Profile") {
                    saveUserProfile()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#b37fc6"))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .font(.custom("AbadiMTProBold", size: 16))
                .padding(.horizontal)
                VStack(spacing: 10) {
                    Toggle("Stream Data", isOn: $isStreaming)
                        .font(.custom("AzoSansRegular", size: 16))
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity)
                        .onChange(of: isStreaming) { _, newValue in
                            assistantService.toggleStreaming(newValue) { success in
                                alertMessage = "Data streaming \(success ? newValue ? "enabled" : "disabled" : "failed")"
                                showAlert = true
                                assistantService.speak(alertMessage)
                            }
                        }
                    Text("Stream Data: \(isStreaming ? "Enabled" : "Disabled")")
                        .font(.custom("AzoSansRegular", size: 14))
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity)
                }
                Spacer()
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("User Profile")
                        .font(.custom("AbadiMTProBold", size: 20))
                        .foregroundColor(Color(hex: "#803a99"))
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Log Out") {
                        walletService.clear()
                        path = NavigationPath()
                    }
                        .font(.custom("AzoSansRegular", size: 16))
                        .foregroundColor(Color(hex: "#803a99"))
                }
            }
            .background(Color(hex: "#4f225b"))
            .alert(isPresented: $showMnemonicAlert) {
                Alert(
                    title: Text("Confirm"),
                    message: Text("Are you sure you want to reveal your mnemonic?"),
                    primaryButton: .default(Text("Yes")) {
                        if let mnemonic = walletService.keychain.read(key: "wallet_mnemonic") {
                            self.mnemonic = mnemonic
                            showMnemonic = true
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Success"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                loadUserProfile()
                address = walletService.loadAddress()
                mnemonic = walletService.keychain.read(key: "wallet_mnemonic")
            }
        }
    }

    private func shortenAddress(_ address: String) -> String {
        "\(address.prefix(6))...\(address.suffix(6))"
    }

    private func loadUserProfile() {
        if let mnemonic = walletService.keychain.read(key: "wallet_mnemonic"),
           let profileData = walletService.keychain.read(key: "user_profile_\(mnemonic)"),
           let profile = try? JSONSerialization.jsonObject(with: Data(profileData.utf8)) as? [String: String] {
            email = profile["email"] ?? ""
            dob = profile["dob"] ?? ""
        }
    }

    private func saveUserProfile() {
        if let mnemonic = walletService.keychain.read(key: "wallet_mnemonic") {
            let profile = ["email": email, "dob": dob]
            if let profileData = try? JSONSerialization.data(withJSONObject: profile) {
                _ = walletService.keychain.save(key: "user_profile_\(mnemonic)", value: String(data: profileData, encoding: .utf8)!)
                alertMessage = "Profile saved"
                showAlert = true
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
