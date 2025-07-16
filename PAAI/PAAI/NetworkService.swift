import Foundation

class NetworkService {
    static let shared = NetworkService()
    private let apiUrl = "https://api.x.ai/v1/chat/completions"
    
    // Load API key from environment or configuration
    private var apiKey: String {
        // First try to get from environment variable
        if let envKey = ProcessInfo.processInfo.environment["XAI_API_KEY"] {
            return envKey
        }
        
        // Fallback to a local config file (not tracked in git)
        if let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: configPath),
           let key = config["XAI_API_KEY"] as? String {
            return key
        }
        
        // Return empty string if not found (will cause auth error)
        return ""
    }

    func getGrokResponse(input: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: apiUrl) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": "grok-3",
            "messages": [["role": "user", "content": input]],
            "max_tokens": 500
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: String],
                  let content = message["content"] else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            completion(.success(content))
        }.resume()
    }
} 