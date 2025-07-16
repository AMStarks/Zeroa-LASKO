import SwiftUI

// MARK: - Design System
struct DesignSystem {
    
    // MARK: - Colors
    struct Colors {
        static let primary = Color(hex: "#4f225b")
        static let secondary = Color(hex: "#b37fc6")
        static let accent = Color(hex: "#803a99")
        static let light = Color(hex: "#d6b8db")
        static let background = Color(hex: "#4f225b")
        static let surface = Color(hex: "#4f225b").opacity(0.1)
        static let text = Color.white
        static let textSecondary = Color.white.opacity(0.8)
        static let error = Color.red
        static let success = Color.green
        static let warning = Color.orange
    }
    
    // MARK: - Typography
    struct Typography {
        static let titleLarge = Font.custom("AbadiMTProBold", size: 32)
        static let titleMedium = Font.custom("AbadiMTProBold", size: 24)
        static let titleSmall = Font.custom("AbadiMTProBold", size: 20)
        static let headline = Font.custom("AbadiMTProBold", size: 18)
        static let bodyLarge = Font.custom("AzoSansRegular", size: 16)
        static let bodyMedium = Font.custom("AzoSansRegular", size: 14)
        static let bodySmall = Font.custom("AzoSansRegular", size: 12)
        static let caption = Font.custom("AzoSansRegular", size: 10)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 25
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let small = Color.black.opacity(0.1)
        static let medium = Color.black.opacity(0.15)
        static let large = Color.black.opacity(0.2)
    }
}

// MARK: - Reusable Components
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    let isLoading: Bool
    
    init(_ title: String, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(DesignSystem.Colors.secondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge))
        }
        .disabled(isLoading)
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(DesignSystem.Colors.light)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge))
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
}

struct InputField: View {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    
    init(_ placeholder: String, text: Binding<String>, isSecure: Bool = false) {
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
    }
    
    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .font(DesignSystem.Typography.bodyLarge)
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.light.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
}

struct CardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
            .shadow(color: DesignSystem.Shadows.small, radius: 4, x: 0, y: 2)
    }
}

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.secondary))
                .scaleEffect(1.2)
            
            Text(message)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: (() -> Void)?
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.error)
            
            Text(message)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            if let retryAction = retryAction {
                PrimaryButton("Retry", action: retryAction)
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Animations
struct Animations {
    static let spring = Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)
    static let easeInOut = Animation.easeInOut(duration: 0.3)
    static let easeOut = Animation.easeOut(duration: 0.2)
}

// MARK: - Extensions
extension View {
    func primaryButtonStyle() -> some View {
        self
            .font(DesignSystem.Typography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(DesignSystem.Colors.secondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge))
    }
    
    func secondaryButtonStyle() -> some View {
        self
            .font(DesignSystem.Typography.headline)
            .foregroundColor(DesignSystem.Colors.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(DesignSystem.Colors.light)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge))
    }
    
    func cardStyle() -> some View {
        self
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
            .shadow(color: DesignSystem.Shadows.small, radius: 4, x: 0, y: 2)
    }
} 