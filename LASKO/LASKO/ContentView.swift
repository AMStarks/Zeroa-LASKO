import SwiftUI

struct ContentView: View {
    @State private var showingFeed = false
    @State private var showingProfile = false
    @EnvironmentObject var laskoService: LASKOService
    @EnvironmentObject private var authUIState: AuthUIState
    @State private var showApprovalSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark blue background
                Color(red: 0.05, green: 0.08, blue: 0.15)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Modern header with gradient
                    VStack(spacing: 20) {
                        // Logo section with modern design
                        VStack(spacing: 20) {
                            // LASKO Logo
                            Image("LaskoLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 158.7, height: 158.7)
                                .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.3), radius: 15, x: 0, y: 8)
                        }
                        
                        // Modern tagline (thinner)
                        Text("Decentralized Social Media")
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(0.4)
                        
                        // Authentication status
                        if laskoService.isAuthenticatedWithZeroa {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Connected to Zeroa")
                                    .foregroundColor(.green)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(20)
                        } else if authUIState.step == .waiting {
                            HStack {
                                ProgressView()
                                    .tint(.orange)
                                Text("Waiting for Zeroa approval…")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(20)
                            .onAppear {
                                // Poll for response while waiting
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    laskoService.checkForAuthResponse()
                                }
                            }
                        } else if authUIState.step == .approved {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                Text("Approved")
                                    .foregroundColor(.green)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(20)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    showingFeed = true
                                }
                            }
                        } else {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Not connected to Zeroa")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(20)
                        }
                    }
                    .padding(.top, 60)
                    .offset(y: -24)
                    
                    // Modern feature cards with glassmorphism
                    VStack(spacing: 16) {
                        ModernFeatureCard(
                            icon: "message.circle.fill",
                            title: "Decentralized Posts",
                            description: "Your content, your control",
                            gradient: [Color(red: 1.0, green: 0.6, blue: 0.0), Color(red: 1.0, green: 0.4, blue: 0.0)]
                        )
                        
                        ModernFeatureCard(
                            icon: "shield.checkered",
                            title: "Privacy First",
                            description: "No algorithms, no tracking",
                            gradient: [Color(red: 0.2, green: 0.8, blue: 0.6), Color(red: 0.1, green: 0.6, blue: 0.4)]
                        )
                        
                        ModernFeatureCard(
                            icon: "link.circle.fill",
                            title: "Blockchain Powered",
                            description: "Built on Telestai network",
                            gradient: [Color(red: 0.6, green: 0.4, blue: 1.0), Color(red: 0.4, green: 0.2, blue: 0.8)]
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .offset(y: -24)
                    
                    // Action + footer directly under feature cards
                    VStack(spacing: 12) {
                        // Primary action button
                        Button(action: {
                            print("Get Started button tapped")
                            if laskoService.isAuthenticatedWithZeroa {
                                showingFeed = true
                            } else {
                                // Always start explicit connect flow and store request
                                DispatchQueue.main.async {
                                    authUIState.step = .waiting
                                    showApprovalSheet = true
                                }
                                laskoService.requestZeroaAuthentication()
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: laskoService.isAuthenticatedWithZeroa ? "arrow.right.circle.fill" : (authUIState.step == .waiting ? "hourglass.circle.fill" : "lock.circle.fill"))
                                    .font(.system(size: 20, weight: .semibold))
                                
                            Text(laskoService.isAuthenticatedWithZeroa ? "Get Started" : (authUIState.step == .waiting ? "Waiting for Zeroa…" : "Log in via Zeroa"))
                                    .font(.system(size: 18, weight: .semibold, design: .default))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.6, blue: 0.0),
                                        Color(red: 1.0, green: 0.4, blue: 0.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .disabled(authUIState.step == .waiting)
                        
                        // Telestai footer
                        VStack(spacing: 6) {
                            Text("Part of the Telestai Ecosystem")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                            Image("TelestaiLogo")
                                .resizable()
                                .renderingMode(.original)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                                .opacity(0.95)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .frame(minHeight: 0, maxHeight: .infinity, alignment: .bottom)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .background(
                NavigationLink(destination: ModernFeedView()
                        .navigationTitle("LASKO Feed")
                    .navigationBarTitleDisplayMode(.large), isActive: $showingFeed) {
                    EmptyView()
                }
            )
            .background(
                NavigationLink(destination: ModernProfileView()
                        .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.large), isActive: $showingProfile) {
                    EmptyView()
                }
            )
        }
        .onAppear {
            // If Zeroa isn't installed/running and button is tapped, the request will be stored.
            // No auto-connect here to ensure the user sees the prompt.
        }
        .onChange(of: laskoService.isAuthenticatedWithZeroa, initial: false) { _, isAuthed in
            if isAuthed {
                // When auth completes, mark approved and navigate to the feed
                DispatchQueue.main.async {
                    authUIState.step = .approved
                    showingFeed = true
                }
            }
        }
        .sheet(isPresented: $showApprovalSheet) {
            ZeroaApprovalSheet()
                .environmentObject(laskoService)
                .environmentObject(authUIState)
        }
    }
}

// Modern feature card with glassmorphism effect
struct ModernFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let gradient: [Color]
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .shadow(color: gradient[0].opacity(0.25), radius: 6, x: 0, y: 3)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}

// Modern feed view inspired by X, Nostr, and Mastodon
struct ModernFeedView: View {
    @EnvironmentObject var laskoService: LASKOService
    @State private var showingPostComposer = false
    @State private var selectedPost: Post?
    @State private var showFluxDriveSheet = false
    @State private var showSubscriptionSheet = false
    @State private var showSettingsSheet = false
    @State private var showSupportSheet = false
    @State private var showSideMenu = false
    
    var body: some View {
        ZStack {
            // Dark blue background
            Color(red: 0.05, green: 0.08, blue: 0.15)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with logo, profile and menu
                HStack {
                    // Profile image (36x36) - top left
                    NavigationLink(destination: ModernProfileView()) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0))
                    }
                    
                    Spacer()
                    
                    // Logo (36x36) - center top (SVG)
                    Image("LaskoFullLogo")
                        .renderingMode(.original)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                        
                    Spacer()
                        
                    // Hamburger menu (top right) - opens slide-out menu
                    Button(action: { withAnimation(.easeInOut(duration: 0.25)) { showSideMenu = true } }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)
                .sheet(isPresented: $showFluxDriveSheet) { FluxDriveView() }
                .sheet(isPresented: $showSubscriptionSheet) { SubscriptionSheetView() }
                .sheet(isPresented: $showSettingsSheet) { LASKOSettingsView() }
                .sheet(isPresented: $showSupportSheet) { LASKOSupportView() }
                
                // Posts feed
                if laskoService.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 1.0, green: 0.6, blue: 0.0)))
                        .scaleEffect(1.5)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(laskoService.posts) { post in
                                ModernPostCard(post: post) {
                                    selectedPost = post
                                }
                                .background(
                                    NavigationLink(isActive: Binding(
                                        get: { selectedPost?.id == post.id },
                                        set: { active in if !active { selectedPost = nil } }
                                    )) {
                                        CommentsView(postId: post.id, sequentialCode: post.id)
                                            .navigationTitle("Comments")
                                            .navigationBarTitleDisplayMode(.inline)
                                    } label: { EmptyView() }
                                    .hidden()
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100) // Extra padding for floating button
                    }
                    // If unauthenticated, show a small inline banner but still show feed
                    if !laskoService.isAuthenticatedWithZeroa {
                        HStack(spacing: 10) {
                            Image(systemName: "link.circle.fill").foregroundColor(.orange)
                            Text("Connect to Zeroa to post and comment")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Button("Connect") { laskoService.requestZeroaAuthentication() }
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                    }
                }
            }
            
            // Slide-out side menu overlay
            if showSideMenu {
                // Dimmed backdrop
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.25)) { showSideMenu = false } }
                // Panel
                LASKOSideMenuView(close: {
                    withAnimation(.easeInOut(duration: 0.25)) { showSideMenu = false }
                }, openFluxDrive: {
                    withAnimation(.easeInOut(duration: 0.25)) { showSideMenu = false }
                    showFluxDriveSheet = true
                }, openSubscription: {
                    withAnimation(.easeInOut(duration: 0.25)) { showSideMenu = false }
                    showSubscriptionSheet = true
                }, openSettings: {
                    withAnimation(.easeInOut(duration: 0.25)) { showSideMenu = false }
                    showSettingsSheet = true
                }, openSupport: {
                    withAnimation(.easeInOut(duration: 0.25)) { showSideMenu = false }
                    showSupportSheet = true
                })
                .transition(.move(edge: .trailing))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }

            // Floating create post button (only show if authenticated)
            if laskoService.isAuthenticatedWithZeroa {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingPostComposer = true
                        }) {
                            Image(systemName: "pencil.and.outline")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 1.0, green: 0.6, blue: 0.0),
                                                    Color(red: 1.0, green: 0.4, blue: 0.0)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.4), radius: 12, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingPostComposer) {
            ModernPostComposerView()
        }
        .onAppear {
            Task {
                await laskoService.fetchPosts()
            }
        }
    }
}

// Modern post card design inspired by X, Nostr, and Mastodon
struct ModernPostCard: View {
    let post: Post
    let onTap: () -> Void
    @EnvironmentObject var laskoService: LASKOService
    @State private var isCommented: Bool = false
    @State private var isAnnounced: Bool = false
    @State private var isLiked: Bool = false
    @State private var likesCount: Int = 0
    @State private var showReplies: Bool = false
    @State private var inlineReplyText: String = ""
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                // Post header
                HStack(spacing: 12) {
                    // User avatar (URL-backed if present)
                    if let urlStr = post.avatarURL, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                        }
                        .frame(width: 29, height: 29)
                        .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.6, blue: 0.0),
                                            Color(red: 1.0, green: 0.4, blue: 0.0)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 29, height: 29)
                            Text(String(post.author.prefix(1)))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Username and time inline to the right
                    HStack(spacing: 8) {
                        Text(post.author.isEmpty ? "User" : post.author)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text(timeAgoString(from: post.timestamp))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Rank icon based on user rank
                    if let rankImageName = getRankImageName(for: post.userRank) {
                        Image(systemName: rankImageName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0)) // Orange theme color
                            .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.6), radius: 8, x: 0, y: 0)
                    }
                }
                
                // Post content
                Text(post.content)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // LAS sequential code (for verification)
                Text("LAS: \(post.id)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Post actions (evenly spaced across the card)
                HStack(spacing: 0) {
                    // Message (comment) first
                    Button(action: {
                        isCommented.toggle()
                        withAnimation { showReplies.toggle() }
                        // Prefetch comments regardless of displayed count
                        Task { await laskoService.fetchComments(forSequentialCode: post.id) }
                        if showReplies {
                            // already fetched above; toggle visibility
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "message")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isCommented ? Color(red: 0.35, green: 0.75, blue: 1.0) : .white.opacity(0.6))
                            Text("\(post.replies)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(isCommented ? Color(red: 0.35, green: 0.75, blue: 1.0) : .white.opacity(0.9))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    // Broadcast (share)
                    Button(action: { isAnnounced.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "megaphone")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isAnnounced ? .green : .white.opacity(0.6))
                            Text("0")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(isAnnounced ? .green : .white.opacity(0.9))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    // Fire (like)
                    Button(action: {
                        isLiked.toggle()
                        likesCount += isLiked ? 1 : -1
                        Task { await LASKOService().likePost(post) }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "flame.fill" : "flame")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isLiked ? .red : .white.opacity(0.6))
                            Text("\(likesCount)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(isLiked ? .red : .white.opacity(0.9))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()
                    
                    // Telestai reward button with transient +10 TLS
                    TelestaiRewardActionButton()
                    
                    Spacer()

                    // Function button
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Inline replies section
                if showReplies {
                    VStack(alignment: .leading, spacing: 8) {
                        if let replies = laskoService.repliesByCode[post.id], !replies.isEmpty {
                            ForEach(replies) { r in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(r.author)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text(timeAgoString(from: r.timestamp))
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    Text(r.content)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.95))
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(10)
                            }
                        } else {
                            Text("No replies yet.")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        // Inline reply composer
                        HStack(spacing: 8) {
                            TextField("Write a reply…", text: $inlineReplyText)
                                .textFieldStyle(.roundedBorder)
                            Button("Reply") {
                                let text = inlineReplyText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !text.isEmpty else { return }
                                Task {
                                    let ok = await laskoService.createComment(content: text, parentSequentialCode: post.id)
                                    if ok {
                                        inlineReplyText = ""
                                        await laskoService.fetchComments(forSequentialCode: post.id)
                                    }
                                }
                            }
                            .disabled(inlineReplyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .onAppear {
                // Initialize local state from the incoming post
                isLiked = post.isLiked
                likesCount = post.likes
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d"
        }
    }
}

// Telestai reward button component
struct TelestaiRewardActionButton: View {
    @State private var showReward = false
    private let gold = Color(red: 156/255, green: 152/255, blue: 118/255) // #9C9876
    @State private var isActive = false
    private let inactiveColor = Color.white.opacity(0.6)
    
    var body: some View {
        HStack(spacing: 6) {
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showReward = true
                }
                isActive = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showReward = false
                    }
                    // Let it stay gold; remove next line if we want it to return to gray
                    // isActive = false
                }
            }) {
                // Use TelestaiLogo set to template mode for tint control
                Image("TelestaiLogo")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .foregroundColor(isActive ? gold : inactiveColor)
                    .scaleEffect(showReward ? 1.12 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
            // Reserve horizontal space to avoid layout shift and fade the label
            Text("+10 TLS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(gold)
                .frame(width: 54, alignment: .leading)
                .opacity(showReward ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: showReward)
        }
    }
}

// Modern profile view
struct ModernProfileView: View {
    @EnvironmentObject var laskoService: LASKOService
    @Environment(\.dismiss) private var dismiss
    @State private var showingImagePicker = false
    @State private var showingBannerImagePicker = false
    @State private var showingNameEditor = false
    @State private var showingBioEditor = false
    @State private var profileImage: UIImage?
    @State private var bannerImage: UIImage?
    @State private var username = "LASKO User"
    @State private var bio = "Building the future of decentralized social media on LASKO"
    @State private var tlsAddress = ""
    @State private var scrollOffset: CGFloat = 0
    
    // Remove mock posts; profile should reflect only the current user's real posts
    private var userPosts: [Post] {
        let addr: String? = laskoService.currentTLSAddress ?? (tlsAddress.isEmpty ? nil : tlsAddress)
        return laskoService.posts.filter { p in
            guard let a = addr, !a.isEmpty else { return false }
            return p.author == a
        }
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.08, blue: 0.15)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Clear Banner (no image)
                    ZStack(alignment: .bottomTrailing) {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 120)
                        
                        // Banner image picker button
                        Button(action: {
                            showingBannerImagePicker = true
                        }) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 8)
                    }
                    
                    // Profile content
                    VStack(spacing: 16) {
                        // Profile picture and name section - TOP LEFT layout
                        HStack(alignment: .top, spacing: 16) {
                            // Profile picture - smaller and top left
                            ZStack(alignment: .bottomTrailing) {
                                if let profileImage = profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                        .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.3), radius: 8, x: 0, y: 4)
                                } else {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 1.0, green: 0.6, blue: 0.0),
                                                    Color(red: 1.0, green: 0.4, blue: 0.0)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 60, height: 60)
                                        .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.3), radius: 8, x: 0, y: 4)
                                    
                                    Text("U")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                // Profile image picker button
                                Button(action: {
                                    showingImagePicker = true
                                }) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 20, height: 20)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                            }
                            
                            // Name and TLS address - VERTICAL layout
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(username)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    // Edit name button
                                    Button(action: {
                                        showingNameEditor = true
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    
                                    // User rank badge
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0))
                                        .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.4), radius: 3, x: 0, y: 2)
                                }
                                
                                Text(tlsAddress.isEmpty ? (laskoService.currentTLSAddress ?? "") : tlsAddress)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, -40) // Overlap with banner
                        
                        // Bio
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Bio")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingBioEditor = true
                                }) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            
                            Text(bio)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(3)
                        }
                        .padding(.horizontal, 20)
                        
                        // Compact stats (Twitter-style) - smaller and tucked
                        HStack(spacing: 20) {
                            HStack(spacing: 4) {
                                Text("0")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Posts")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            HStack(spacing: 4) {
                                Text("0")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Following")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            HStack(spacing: 4) {
                                Text("0")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Followers")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        // White page break
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        
                        // User's posts section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Posts")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            // User's posts only
                            LazyVStack(spacing: 12) {
                                ForEach(userPosts, id: \.id) { post in
                                    ModernPostCard(post: post) {}
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $profileImage)
        }
        .sheet(isPresented: $showingBannerImagePicker) {
            ImagePicker(selectedImage: $bannerImage)
        }
        .sheet(isPresented: $showingNameEditor) {
            NameEditorView(username: $username)
        }
        .sheet(isPresented: $showingBioEditor) {
            BioEditorView(bio: $bio)
        }
        .onAppear {
            // Initialize TLS address from service for display
            if tlsAddress.isEmpty {
                tlsAddress = laskoService.currentTLSAddress ?? tlsAddress
            }
        }
    }
}

// Name editor view
struct NameEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var username: String
    @State private var tempUsername: String
    
    init(username: Binding<String>) {
        self._username = username
        self._tempUsername = State(initialValue: username.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Edit Username")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                TextField("Username", text: $tempUsername)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 20)
                
                Button("Save") {
                    username = tempUsername
                    dismiss()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color.orange)
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .background(Color(red: 0.05, green: 0.08, blue: 0.15))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
    }
}

// Bio editor view
struct BioEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bio: String
    @State private var tempBio: String
    
    init(bio: Binding<String>) {
        self._bio = bio
        self._tempBio = State(initialValue: bio.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Edit Bio")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                TextEditor(text: $tempBio)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                
                Button("Save") {
                    bio = tempBio
                    dismiss()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color.orange)
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .background(Color(red: 0.05, green: 0.08, blue: 0.15))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
    }
}

// Composer moved to separate file

// MARK: - Lightweight Formatting Toolbar & Preview
struct FormattingToolbar: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 12) {
            Button(action: { surround(with: "**") }) { Text("B").fontWeight(.bold) }
            Button(action: { surround(with: "*") })  { Text("I").italic() }
            Button(action: { surround(with: "`") })  { Text("Code").font(.caption) }
            Button(action: { text.append("\n\n• ") }) { Text("• List").font(.caption) }
            Spacer()
            Text("\(text.count)/1000")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .foregroundColor(.black)
    }
    private func surround(with token: String) {
        text = token + text + token
    }
}

struct RichPreview: View {
    let text: String
    var body: some View {
        Text(text)
            .foregroundColor(.black)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - Poll Maker & Scheduler Sheets (basic stubs to satisfy compiler)
struct PollMakerSheet: View {
    @Binding var options: [String]
    @Binding var durationHours: Int
    @Environment(\.dismiss) private var dismiss
    @State private var newOption: String = ""
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                HStack {
                    TextField("Add option", text: $newOption)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        if !newOption.trimmingCharacters(in: .whitespaces).isEmpty {
                            options.append(newOption)
                            newOption = ""
                        }
                    }
                }
                .padding(.horizontal)
                Stepper("Duration: \(durationHours)h", value: $durationHours, in: 1...168)
                    .padding(.horizontal)
                List {
                    ForEach(options.indices, id: \.self) { i in
                        Text(options[i])
                    }
                    .onDelete { idx in options.remove(atOffsets: idx) }
                }
                Button("Done") { dismiss() }
                    .padding(.bottom)
            }
            .navigationTitle("Create Poll")
        }
    }
}

struct SchedulerSheet: View {
    @Binding var scheduledDate: Date?
    @Environment(\.dismiss) private var dismiss
    @State private var tempDate: Date = Date().addingTimeInterval(3600)
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                DatePicker("Schedule", selection: $tempDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .padding()
                HStack {
                    Button("Clear") { scheduledDate = nil; dismiss() }
                    Spacer()
                    Button("Set") { scheduledDate = tempDate; dismiss() }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Schedule Post")
        }
    }
}

// MARK: - Styled toolbar elements
private struct ToolbarIcon: View {
    let system: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color.black.opacity(0.06))
                    .frame(width: 32, height: 32)
                Image(systemName: system)
                    .foregroundColor(.black)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ToolbarDivider: View {
    var body: some View { Rectangle().fill(Color.black.opacity(0.08)).frame(width: 1, height: 22) }
}

// Helper function to get rank image name
func getRankImageName(for rank: String) -> String? {
    switch rank {
    case "Bronze":
        return "medal.fill"
    case "Silver":
        return "medal.fill"
    case "Gold":
        return "medal.fill"
    case "Platinum":
        return "crown.fill"
    case "Diamond":
        return "diamond.fill"
    default:
        return nil
    }
}

// Slide-out side menu
struct LASKOSideMenuView: View {
    let close: () -> Void
    let openFluxDrive: () -> Void
    let openSubscription: () -> Void
    let openSettings: () -> Void
    let openSupport: () -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Menu")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().background(Color.white.opacity(0.1))

                Group {
                    sideRowAsset(title: "FluxDrive Storage", assetName: "FluxIcon", action: openFluxDrive)
                    sideRow(title: "Subscription", systemImage: "lock.shield", action: openSubscription)
                    sideRow(title: "Settings", systemImage: "gearshape.fill", action: openSettings)
                    sideRow(title: "Support & Help", systemImage: "questionmark.circle.fill", action: openSupport)
                }
                .padding(.top, 6)

                Spacer()
            }
            .frame(width: 280)
            .background(Color(red: 0.08, green: 0.11, blue: 0.18))
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func sideRow(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0))
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func sideRowAsset(title: String, assetName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(assetName)
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ContentView()
}
