import SwiftUI

struct LASKOAuthRequestView: View {
    let authRequest: LASKOAuthRequest
    @Environment(\.dismiss) private var dismiss
    @State private var isAuthorizing = false
    @StateObject private var authService = LASKOAuthService()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("\(authRequest.appName) wants to use your Zeroa identity")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
                
                // Permissions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Permissions requested:")
                        .font(.headline)
                    
                    ForEach(authRequest.permissionDescriptions, id: \.self) { permission in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16))
                            Text(permission)
                                .font(.system(size: 14))
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: authorizeLASKO) {
                        HStack {
                            if isAuthorizing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(isAuthorizing ? "Authorizing..." : "Authorize Login")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isAuthorizing)
                    
                    Button("Deny") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isAuthorizing)
                }
            }
            .padding()
            .navigationTitle("Zeroa Authorization")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func authorizeLASKO() {
        isAuthorizing = true
        
        Task {
            do {
                // Generate session data
                let session = try await authService.createLASKOAuthSession(permissions: authRequest.permissions)
                
                // Send response to LASKO via App Groups
                authService.sendAuthResponseToLASKO(session)
                
                // Clear the request after successful authorization
                authService.clearAuthRequest()
                
                await MainActor.run {
                    isAuthorizing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isAuthorizing = false
                    // Handle error - show alert or dismiss
                    print("Authorization failed: \(error)")
                    dismiss()
                }
            }
        }
    }
} 