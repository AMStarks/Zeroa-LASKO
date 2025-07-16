import Foundation

class NetworkService {
    static let shared = NetworkService()
    private let apiUrl = "https://api.x.ai/v1/chat/completions"
    
    // Load API key from environment or configuration
    private var apiKey: String {
        // First try to get from environment variable
        if let envKey = ProcessInfo.processInfo.environment["XAI_API_KEY"] {
            print("🔑 API Key loaded from environment variable: \(String(envKey.prefix(10)))...")
            return envKey
        }
        
        // Fallback to a local config file (not tracked in git)
        if let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: configPath),
           let key = config["XAI_API_KEY"] as? String {
            print("🔑 API Key loaded from Config.plist: \(String(key.prefix(10)))...")
            return key
        }
        
        // Return empty string if not found (will cause auth error)
        print("❌ No API key found in environment or config file!")
        return ""
    }

    func getGrokResponse(input: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("🌐 Making API request to: \(apiUrl)")
        print("📝 Input: \(input)")
        
        guard let url = URL(string: apiUrl) else { 
            print("❌ Invalid URL")
            return 
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "grok-3",
            "messages": [["role": "user", "content": input]],
            "max_tokens": 500
        ]
        
        print("🔑 Authorization header: Bearer \(String(apiKey.prefix(10)))...")
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status Code: \(httpResponse.statusCode)")
                print("📡 HTTP Headers: \(httpResponse.allHeaderFields)")
            }
            
            if let data = data {
                print("📦 Response data length: \(data.count) bytes")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📦 Response body: \(responseString)")
                }
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                print("❌ Failed to parse response JSON")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            print("✅ Successfully parsed response")
            print("📄 Content: \(content)")
            completion(.success(content))
        }.resume()
    }
} 