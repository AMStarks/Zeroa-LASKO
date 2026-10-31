import SwiftUI

/// One-time consent before any request to xAI (`api.x.ai`).
struct AIConsentView: View {
    var onAllow: () -> Void
    var onNotNow: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 48))
                        .foregroundColor(DesignSystem.Colors.secondary)
                        .frame(maxWidth: .infinity)

                    Text("AI data sharing")
                        .font(DesignSystem.Typography.titleLarge)
                        .foregroundColor(DesignSystem.Colors.text)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("Zeroa can send the text you type for AI features to xAI, a third-party AI provider, so it can generate responses. This is optional.")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("What we send")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.text)
                        bullet("Your AI prompt / message text")
                        bullet("Optional context we attach, such as your TLS balance figure shown in the app")
                        bullet("Not sent: recovery phrases, private keys, photos, or Switchboard attachments")
                    }
                    .padding(DesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignSystem.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))

                    Link("Read Zeroa’s Privacy Policy", destination: ZeroaAPIConfig.privacyPolicyURL)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.secondary)

                    VStack(spacing: DesignSystem.Spacing.md) {
                        Button(action: onAllow) {
                            Text("Allow")
                                .font(DesignSystem.Typography.bodyMedium.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.md)
                                .background(DesignSystem.Colors.secondary)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                        }
                        .accessibilityIdentifier("ai.consent.allow")

                        Button(action: onNotNow) {
                            Text("Not now")
                                .font(DesignSystem.Typography.bodyMedium.weight(.semibold))
                                .foregroundColor(DesignSystem.Colors.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.md)
                        }
                        .accessibilityIdentifier("ai.consent.notNow")
                    }
                    .padding(.top, DesignSystem.Spacing.sm)
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background.ignoresSafeArea())
            .navigationTitle("AI Consent")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Text("•")
                .foregroundColor(DesignSystem.Colors.secondary)
            Text(text)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
}

struct AIConsentRequiredBanner: View {
    var onEnable: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("AI is turned off")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.text)
            Text("You chose not to share prompts with xAI. You can enable AI data sharing anytime in Settings, or tap Enable below.")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Button("Enable AI data sharing", action: onEnable)
                .font(DesignSystem.Typography.bodyMedium.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.secondary)
                .accessibilityIdentifier("ai.consent.enablePrompt")
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }
}

struct AISettingsConsentCard: View {
    @ObservedObject private var aiConsent = AIConsentManager.shared
    @State private var showConsentSheet = false

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("AI data sharing")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.text)

                Toggle(
                    "Share prompts with xAI",
                    isOn: Binding(
                        get: { aiConsent.hasGrantedConsent },
                        set: { enabled in
                            if enabled && !aiConsent.hasGrantedConsent {
                                showConsentSheet = true
                            } else {
                                aiConsent.setConsentEnabled(enabled)
                            }
                        }
                    )
                )
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.text)
                .accessibilityIdentifier("ai.consent.settingsToggle")

                Text("When on, your AI prompts (and optional balance context) are sent to xAI to generate replies. Recovery phrases and private keys are never sent. See Privacy Policy for details.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Link("Privacy Policy", destination: ZeroaAPIConfig.privacyPolicyURL)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondary)
            }
        }
        .sheet(isPresented: $showConsentSheet) {
            AIConsentView(
                onAllow: {
                    aiConsent.allow()
                    showConsentSheet = false
                },
                onNotNow: {
                    aiConsent.decline()
                    showConsentSheet = false
                }
            )
        }
    }
}
