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
        setupSpeechRecognition()
    }

    // MARK: - Enhanced Speech Synthesis
    func speak(_ text: String, priority: Bool = false) {
        print("🎤 Speaking: \(text)")
        
        // Stop any current speech if priority
        if priority {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.8
        
        DispatchQueue.main.async {
            self.synthesizer.speak(utterance)
        }
    }
    
    func speakWithEmotion(_ text: String, emotion: String = "neutral") {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        switch emotion {
        case "excited":
            utterance.rate = 0.6
            utterance.pitchMultiplier = 1.2
            utterance.volume = 1.0
        case "calm":
            utterance.rate = 0.4
            utterance.pitchMultiplier = 0.9
            utterance.volume = 0.7
        case "urgent":
            utterance.rate = 0.7
            utterance.pitchMultiplier = 1.3
            utterance.volume = 1.0
        default:
            utterance.rate = 0.5
            utterance.pitchMultiplier = 1.0
            utterance.volume = 0.8
        }
        
        DispatchQueue.main.async {
            self.synthesizer.speak(utterance)
        }
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
            
            // Keep only last 10 conversations
            if self.conversationHistory.count > 10 {
                self.conversationHistory.removeFirst()
            }
        }
    }
    
    func getRecentContext() -> String {
        let recent = conversationHistory.suffix(3)
        return recent.map { "User: \($0.userInput)\nAI: \($0.aiResponse)" }.joined(separator: "\n\n")
    }

    // MARK: - Enhanced Streaming
    func toggleStreaming(_ enable: Bool, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            self.isStreaming = enable
        }
        
        if enable, webSocketTask == nil {
            guard let url = URL(string: "wss://data.telestai.io/stream") else {
                print("Invalid WebSocket URL")
                DispatchQueue.main.async {
                    self.isStreaming = false
                    self.startMockStreaming()
                    completion(true)
                }
                return
            }
            
            webSocketTask = URLSession.shared.webSocketTask(with: url)
            receiveWebSocketMessages()
            webSocketTask?.resume()
            
            let message = [
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "action": "app_usage",
                "user_id": WalletService.shared.loadAddress() ?? "unknown"
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: message) {
                webSocketTask?.send(.string(String(data: data, encoding: .utf8)!)) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("WebSocket send error: \(error.localizedDescription)")
                            self.isStreaming = false
                            self.webSocketTask = nil
                            self.startMockStreaming()
                            completion(true)
                        } else {
                            print("Streaming enabled")
                            completion(true)
                        }
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

    private func receiveWebSocketMessages() {
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
                    self.receiveWebSocketMessages()
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
                        speak("Your balance has been updated to \(String(format: "%.6f", balance)) TLS")
                    }
                case "transaction_confirmed":
                    if let txid = json["txid"] as? String {
                        speak("Transaction confirmed: \(String(txid.prefix(8)))...")
                    }
                case "subscription_expiring":
                    speak("Your subscription will expire soon. Please renew to continue using AI services.")
                default:
                    print("Unknown stream event: \(event)")
                }
            }
        }
    }

    // MARK: - Speech Recognition
    private func setupSpeechRecognition() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied:
                    print("Speech recognition denied")
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
    
    func startListening(completion: @escaping (String?) -> Void) {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            completion(nil)
            return
        }
        
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            DispatchQueue.main.async {
                self.isListening = false
            }
            return
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .dontDeactivateOnSilence)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                completion(nil)
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            DispatchQueue.main.async {
                self.isListening = true
            }
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        DispatchQueue.main.async {
                            self.isListening = false
                        }
                        completion(transcript)
                    }
                } else if let error = error {
                    print("Speech recognition error: \(error)")
                    DispatchQueue.main.async {
                        self.isListening = false
                    }
                    completion(nil)
                }
            }
            
        } catch {
            print("Speech recognition setup error: \(error)")
            completion(nil)
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        DispatchQueue.main.async {
            self.isListening = false
        }
    }

    // MARK: - AI Response Enhancement
    func generateContextualResponse(to input: String, context: [String: Any] = [:]) -> String {
        // Enhanced AI response generation with context
        let userAddress = WalletService.shared.loadAddress() ?? "unknown"
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
