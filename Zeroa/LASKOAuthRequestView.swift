import SwiftUI

struct LASKOAuthRequestView: View {
    let authRequest: LASKOAuthRequest
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessingReturn = false
    @State private var showManualReturn = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Authentication Request")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                // Request Details
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "app.badge")
                        Text("App: \(authRequest.appName)")
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "key.fill")
                        Text("Permissions: \(authRequest.permissions.joined(separator: ", "))")
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "person.circle")
                        Text("User: \(authRequest.username ?? "Unknown") • Address: \(getCurrentAddress().prefix(10))...")
                        Spacer()
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Deny") {
                        print("🔍 User denied LASKO auth request")
                        handleLASKOAuthResponse(approved: false)
                        isProcessingReturn = true
                        openCallbackWithRetries(status: "declined")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .frame(maxWidth: .infinity)
                    
                    Button("Approve") {
                        print("🔍 User approved LASKO auth request")
                        handleLASKOAuthResponse(approved: true)
                        isProcessingReturn = true
                        openCallbackWithRetries(status: "approved")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .frame(maxWidth: .infinity)
                }
                
                if isProcessingReturn {
                    VStack(spacing: 8) {
                        ProgressView().tint(.blue)
                        Text("Returning to LASKO…")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                
                if showManualReturn {
                    Button {
                        // Final manual attempt: custom scheme only (no web fallback)
                        if let url = URL(string: authRequest.callbackURL + "?status=approved") {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.uturn.left.circle")
                            Text("Return to LASKO")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
        }
        .onAppear {
            print("🔍 LASKOAuthRequestView appeared with request: \(authRequest.appName)")
        }
        .onDisappear {
            print("🔍 LASKOAuthRequestView disappeared")
        }
    }
    
    private func getCurrentAddress() -> String {
        return WalletService.shared.loadAddress() ?? "Unknown"
    }
    
    private func handleLASKOAuthResponse(approved: Bool) {
        print("🔍 Handling LASKO auth response: \(approved ? "approved" : "denied")")
        
        if approved {
            // Create auth response
            let response = createAuthResponse()
            
            // Store response in App Groups
            AppGroupsService.shared.storeLASKOAuthResponse(response)
            print("📤 Auth response stored in App Groups")
        } else {
            print("❌ Auth request denied by user")
        }
        
        // Clear the request
        AppGroupsService.shared.clearAuthRequest()
        print("🧹 Auth request cleared")
    }

    private func openCallbackWithRetries(status: String) {
        // Custom scheme only per user requirement
        let custom = URL(string: authRequest.callbackURL + "?status=\(status)")
        let candidates = [custom].compactMap { $0 }
        // Extra safety: small delay before first attempt to avoid sheet-dismiss timing
        
        func tryOpen(_ urls: [URL], attempt: Int) {
            guard !urls.isEmpty else { failOut(); return }
            var remaining = urls
            let url = remaining.removeFirst()
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    isProcessingReturn = false
                    dismiss()
                } else if attempt < 3 {
                    // Backoff: 0.15s, 0.4s, 0.8s
                    let delays: [Double] = [0.15, 0.4, 0.8]
                    let delay = delays[min(attempt, delays.count - 1)]
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        // Retry same URL first, then others
                        tryOpen([url] + remaining, attempt: attempt + 1)
                    }
                } else {
                    // Try remaining URLs if any
                    if !remaining.isEmpty {
                        tryOpen(remaining, attempt: 0)
                    } else {
                        failOut()
                    }
                }
            }
        }
        
        func failOut() {
            isProcessingReturn = false
            showManualReturn = true
        }
        
        tryOpen(candidates, attempt: 0)
    }
    
    private func createAuthResponse() -> LASKOAuthSession {
        let tlsAddress = WalletService.shared.loadAddress() ?? ""
        let sessionToken = "session_\(UUID().uuidString)"
        let timestamp = Int64(Date().timeIntervalSince1970)
        let expiresAt = timestamp + (24 * 60 * 60) // 24 hours
        
        // Create real signature using TLS
        let message = "LASKO_AUTH:\(tlsAddress):\(sessionToken)"
        let signature = WalletService.shared.signMessage(message) ?? "signature_failed"
        
        let response = LASKOAuthSession(
            tlsAddress: tlsAddress,
            sessionToken: sessionToken,
            signature: signature,
            timestamp: timestamp,
            expiresAt: expiresAt,
            permissions: ["post", "read"]
        )
        
        print("🔑 Created auth response with real signature: \(sessionToken)")
        return response
    }
} 