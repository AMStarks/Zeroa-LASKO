import Foundation
import AVFoundation
import Combine

class AssistantService: ObservableObject {
    static let shared = AssistantService()
    @Published var isStreaming = false
    private var webSocketTask: URLSessionWebSocketTask?
    private let synthesizer = AVSpeechSynthesizer()
    private var mockStreamTimer: Timer?

    func speak(_ text: String) {
        print("Speaking: \(text)")
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        DispatchQueue.main.async {
            self.synthesizer.speak(utterance)
        }
    }

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
            let message = ["timestamp": ISO8601DateFormatter().string(from: Date()), "action": "app_usage"]
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
            print("Mock stream data: {\"timestamp\": \"\(ISO8601DateFormatter().string(from: Date()))\", \"event\": \"mock_usage\"}")
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
}
