import SwiftUI

struct ProfileView: View {
    @StateObject private var service = LASKOService()
    @State private var username = "lasko_user"
    @State private var postsCount = 42
    @State private var followersCount = 128
    @State private var followingCount = 64
    @State private var showingBlockchainStatus = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("LaskoBackground")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        VStack(spacing: 16) {
                            // Avatar
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text("L")
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.white)
                                )
                            
                            // Username
                            Text(username)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            // Bio
                            Text("Building the future of decentralized social media on LASKO")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Stats
                        HStack(spacing: 40) {
                            VStack {
                                Text("\(postsCount)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("Posts")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            VStack {
                                Text("\(followersCount)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("Followers")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            VStack {
                                Text("\(followingCount)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("Following")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding()
                        .background(Color("LaskoCardBackground"))
                        .cornerRadius(12)
                        
                        // Blockchain Status
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Blockchain Status")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button("View Details") {
                                    showingBlockchainStatus = true
                                }
                                .font(.caption)
                                .foregroundColor(Color.accentColor)
                            }
                            
                            HStack {
                                Circle()
                                    .fill(service.isConnectedToTelestai ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                
                                Text(service.isConnectedToTelestai ? "Connected to Telestai" : "Disconnected")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color("LaskoCardBackground"))
                        .cornerRadius(12)
                        
                        // Settings Section
                        VStack(spacing: 12) {
                            SettingsRow(icon: "person.fill", title: "Edit Profile", action: {})
                            SettingsRow(icon: "shield.fill", title: "Privacy Settings", action: {})
                            SettingsRow(icon: "bell.fill", title: "Notifications", action: {})
                            SettingsRow(icon: "gear", title: "App Settings", action: {})
                            SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", action: {})
                        }
                        .padding()
                        .background(Color("LaskoCardBackground"))
                        .cornerRadius(12)
                        
                        // About LASKO
                        VStack(alignment: .leading, spacing: 12) {
                            Text("About LASKO")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("LASKO is a decentralized social media platform built on the Telestai blockchain. Your content, your control.")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .background(Color("LaskoCardBackground"))
                        .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingBlockchainStatus) {
                NavigationView {
                    BlockchainStatusView()
                        .navigationTitle("Blockchain Status")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingBlockchainStatus = false
                                }
                                .foregroundColor(Color.accentColor)
                            }
                        }
                }
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color.accentColor)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.caption)
            }
        }
    }
}

#Preview {
    ProfileView()
} 