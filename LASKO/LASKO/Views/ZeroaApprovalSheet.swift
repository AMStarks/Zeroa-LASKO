import SwiftUI

struct ZeroaApprovalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var laskoService: LASKOService
    @EnvironmentObject var authUIState: AuthUIState
    
    @State private var showingApproved = false
    @State private var pollTimer: Timer?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: showingApproved ? "checkmark.seal.fill" : "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundColor(showingApproved ? .green : .blue)
                .padding(.top, 8)
            
            Text(showingApproved ? "Approved" : "Connect with Zeroa")
                .font(.title2).bold()
                .foregroundColor(.white)
            
            Text(showingApproved ? "You're connected to Zeroa."
                 : "Approve this request in Zeroa to let LASKO access your TLS address and post on your behalf.")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 16)
            
            if !showingApproved {
                VStack(spacing: 12) {
                    Button {
                        // Open Zeroa approval screen via custom scheme only
                        if let url = URL(string: "zeroa://auth/request") {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.right.square")
                            Text("Open Zeroa to Approve")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    
                    Button {
                        // Fallback: guide to download (wire real App Store URL later)
                        if let url = URL(string: "https://apps.apple.com") {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Download Zeroa")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.white)
                }
                .padding(.top, 6)
            }
            
            Spacer(minLength: 8)
        }
        .padding(20)
        .background(Color(red: 0.15, green: 0.15, blue: 0.15)) // Force charcoal background
        .presentationDetents([.height(320), .medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Start polling every 0.5s while the sheet is visible
            pollTimer?.invalidate()
            pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                Task { await laskoService.checkForAuthResponse() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Re-check when returning from Zeroa
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                laskoService.checkForAuthResponse()
            }
        }
        .onChange(of: laskoService.isAuthenticatedWithZeroa, initial: false) { _, isAuthed in
            if isAuthed {
                withAnimation(.spring()) {
                    showingApproved = true
                    authUIState.step = .approved
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    pollTimer?.invalidate()
                    dismiss()
                }
            }
        }
        .onDisappear {
            pollTimer?.invalidate()
        }
    }
}

