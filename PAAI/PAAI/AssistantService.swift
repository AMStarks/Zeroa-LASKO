import Foundation
import AVFoundation
import Combine

// MARK: - AI Context Management
struct AIConversationContext {
    let timestamp: Date
    let userInput: String
    let aiResponse: String
    let action: String?
    let parameters: [String: Any]?
}

// MARK: - Enhanced Assistant Service
class AssistantService: ObservableObject {
    static let shared = AssistantService()
    @Published var isStreaming = false
    @Published var isListening = false
    @Published var conversationHistory: [AIConversationContext] = []
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let synthesizer = AVSpeechSynthesizer()
    private var mockStreamTimer: Timer?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        // Voice functionality completely disabled
        print("🎤 AssistantService initialized with voice disabled")
    }

    // MARK: - Enhanced Speech Synthesis (DISABLED)
    func speak(_ text: String, priority: Bool = false) {
        print("🎤 Speaking disabled: \(text)")
        // Voice synthesis disabled
    }
    
    func speakWithEmotion(_ text: String, emotion: String = "neutral") {
        print("🎤 Speaking with emotion disabled: \(text) (\(emotion))")
        // Voice synthesis disabled
    }

    // MARK: - Context Management
    func addToConversationHistory(input: String, response: String, action: String? = nil, parameters: [String: Any]? = nil) {
        let context = AIConversationContext(
            timestamp: Date(),
            userInput: input,
            aiResponse: response,
            action: action,
            parameters: parameters
        )
        
        DispatchQueue.main.async {
            self.conversationHistory.append(context)
            
            // Keep only last 50 conversations
            if self.conversationHistory.count > 50 {
                self.conversationHistory.removeFirst()
            }
        }
    }
    
    func getRecentContext() -> String {
        let recentContexts = conversationHistory.suffix(5)
        return recentContexts.map { context in
            """
            User: \(context.userInput)
            Assistant: \(context.aiResponse)
            """
        }.joined(separator: "\n\n")
    }

    // MARK: - Streaming Management
    func toggleStreaming(enable: Bool, completion: @escaping (Bool) -> Void) {
        if enable {
            guard let walletAddress = WalletService.shared.loadAddress() else {
                print("❌ No wallet address found for streaming")
                completion(false)
                return
            }
            
            guard let url = URL(string: "wss://stream.zeroa.app/ws") else {
                print("❌ Invalid streaming WebSocket URL")
                completion(false)
                return
            }
            
            webSocketTask = URLSession.shared.webSocketTask(with: url)
            webSocketTask?.resume()
            
            let connectionMessage = [
                "type": "connect",
                "wallet_address": walletAddress,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: connectionMessage),
               let messageString = String(data: data, encoding: .utf8) {
                webSocketTask?.send(.string(messageString)) { error in
                    if let error = error {
                        print("❌ WebSocket connection error: \(error)")
                        DispatchQueue.main.async {
                            self.isStreaming = false
                            self.webSocketTask = nil
                            self.startMockStreaming()
                            completion(true)
                        }
                    } else {
                        print("✅ Connected to streaming service")
                        DispatchQueue.main.async {
                            self.isStreaming = true
                            self.stopMockStreaming()
                        }
                        Task {
                            await self.startReceivingStreamMessages()
                        }
                        completion(true)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isStreaming = false
                    self.webSocketTask = nil
                    self.startMockStreaming()
                    completion(true)
                }
            }
        } else if !enable, let task = webSocketTask {
            task.cancel(with: .normalClosure, reason: nil)
            DispatchQueue.main.async {
                self.webSocketTask = nil
                self.isStreaming = false
                self.stopMockStreaming()
                print("Streaming disabled")
                completion(true)
            }
        } else {
            DispatchQueue.main.async {
                self.stopMockStreaming()
                completion(true)
            }
        }
    }

    private func startMockStreaming() {
        stopMockStreaming()
        mockStreamTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            let mockData = [
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "event": "mock_usage",
                "user_id": WalletService.shared.loadAddress() ?? "unknown",
                "app_activity": "ai_interaction"
            ]
            print("Mock stream data: \(mockData)")
        }
    }

    private func stopMockStreaming() {
        mockStreamTimer?.invalidate()
        mockStreamTimer = nil
        print("Mock streaming stopped")
    }

    private func startReceivingStreamMessages() async {
        webSocketTask?.receive { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        print("Stream data: \(text)")
                        self.handleStreamMessage(text)
                    case .data:
                        print("Received binary data")
                    @unknown default:
                        print("Unknown message type")
                    }
                    Task {
                        await self.startReceivingStreamMessages()
                    }
                case .failure(let error):
                    print("Stream error: \(error.localizedDescription)")
                    self.isStreaming = false
                    self.webSocketTask = nil
                    self.startMockStreaming()
                }
            }
        }
    }
    
    private func handleStreamMessage(_ message: String) {
        // Handle incoming stream messages
        if let data = message.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            if let event = json["event"] as? String {
                switch event {
                case "balance_update":
                    if let balance = json["balance"] as? Double {
                        // speak("Your balance has been updated to \(String(format: "%.6f", balance)) TLS")
                        print("💰 Balance updated: \(String(format: "%.6f", balance)) TLS")
                    }
                case "transaction_confirmed":
                    if let txid = json["txid"] as? String {
                        // speak("Transaction confirmed: \(String(txid.prefix(8)))...")
                        print("✅ Transaction confirmed: \(String(txid.prefix(8)))...")
                    }
                case "subscription_expiring":
                    // speak("Your subscription will expire soon. Please renew to continue using AI services.")
                    print("⚠️ Subscription expiring soon")
                default:
                    print("Unknown stream event: \(event)")
                }
            }
        }
    }

    // MARK: - Speech Recognition (DISABLED)
    private func setupSpeechRecognition() {
        // Speech recognition completely disabled
        print("🎤 Speech recognition disabled")
    }
    
    func startListening(completion: @escaping (String?) -> Void) {
        print("🎤 Speech recognition disabled")
        completion(nil)
    }
    
    func stopListening() {
        print("🎤 Speech recognition disabled")
    }

    // MARK: - AI Response Enhancement
    func generateContextualResponse(to input: String, context: [String: Any] = [:]) -> String {
        // Enhanced AI response generation with context
        let balance = context["balance"] as? Double ?? 0.0
        let isSubscribed = WalletService.shared.checkSubscription()
        
        var response = ""
        
        if input.lowercased().contains("hello") || input.lowercased().contains("hi") {
            response = "Hello! I'm your PAAI assistant. How can I help you today?"
        } else if input.lowercased().contains("balance") {
            response = "Your current balance is \(String(format: "%.6f", balance)) TLS"
        } else if input.lowercased().contains("subscription") {
            if isSubscribed {
                response = "Your subscription is active and valid."
            } else {
                response = "You need to subscribe to use AI services. The cost is 10 TLS per month."
            }
        } else if input.lowercased().contains("help") {
            response = "I can help you with: scheduling meetings, checking blockchain stats, signing messages, sending payments, and more. Just ask!"
        } else {
            response = "I understand you're asking about \(input). Let me process that for you."
        }
        
        return response
    }
    
    // MARK: - Utility Methods
    func clearConversationHistory() {
        DispatchQueue.main.async {
            self.conversationHistory.removeAll()
        }
    }
    
    func getConversationSummary() -> String {
        let totalInteractions = conversationHistory.count
        let recentInteractions = conversationHistory.suffix(5).count
        return "You've had \(totalInteractions) interactions with me, including \(recentInteractions) recent ones."
    }
}

// MARK: - Extensions
import Speech

extension AssistantService {
    func requestSpeechRecognitionPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition permission granted")
                case .denied:
                    print("Speech recognition permission denied")
                case .restricted:
                    print("Speech recognition restricted")
                case .notDetermined:
                    print("Speech recognition not determined")
                @unknown default:
                    print("Speech recognition unknown status")
                }
            }
        }
    }
}
