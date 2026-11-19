import SwiftUI

/// Settings → Delete Account. Deletes the Halo account for this wallet, then wipes this device.
struct DeleteAccountView: View {
    let onDeleted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showPhrase = false
    @State private var backedUp = false
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private var recoveryPhrase: String {
        WalletService.shared.keychain.read(key: "wallet_mnemonic") ?? ""
    }

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        Text("Delete Account")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.text)

                        Text("This permanently deletes your Zeroa account and the account data Halo stores for this wallet address. That includes your Halo sign-in and any indexed posts tied to the address.")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text("Deleting your account does not affect on-chain funds. Coins already on the blockchain stay there. This device will forget the wallet, so you can only reach those funds again if you have backed up the recovery phrase.")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.text)

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Text("Recovery phrase")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.text)
                                Spacer()
                                Button(showPhrase ? "Hide" : "Show") {
                                    showPhrase.toggle()
                                }
                                .foregroundColor(DesignSystem.Colors.secondary)
                            }
                            Text(showPhrase ? (recoveryPhrase.isEmpty ? "No recovery phrase is stored on this device." : recoveryPhrase) : String(repeating: "•", count: 24))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(DesignSystem.Colors.text)
                                .textSelection(.enabled)
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Toggle("I have written down my recovery phrase", isOn: $backedUp)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.text)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.error)
                        }

                        Button(action: { confirmDelete = true }) {
                            HStack {
                                if isDeleting { ProgressView() }
                                Text(isDeleting ? "Deleting…" : "Delete Account")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(backedUp && !isDeleting ? DesignSystem.Colors.error : DesignSystem.Colors.error.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(!backedUp || isDeleting || recoveryPhrase.isEmpty)
                        .accessibilityIdentifier("settings.deleteAccount.confirm")
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isDeleting)
                }
            }
        }
        .alert("Delete this account?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Account", role: .destructive) {
                Task { await performDeletion() }
            }
        } message: {
            Text("Halo will delete the account data for this wallet. On-chain funds are not affected. This cannot be undone on this device.")
        }
        .interactiveDismissDisabled(isDeleting)
    }

    @MainActor
    private func performDeletion() async {
        guard !isDeleting else { return }
        isDeleting = true
        errorMessage = nil
        do {
            try await HaloService.shared.deleteAccount()
            wipeLocalAccount()
            onDeleted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isDeleting = false
        }
    }

    private func wipeLocalAccount() {
        HaloAPIService.shared.clearStoredToken()
        WalletService.shared.clear()
        _ = WalletService.shared.keychain.deleteAll()
        let defaults = AppGroupsService.shared.sharedDefaults
        defaults?.removeObject(forKey: "tls_wallet_address")
        defaults?.removeObject(forKey: "flux_wallet_address")
        defaults?.synchronize()
        for key in [
            "wallet_address",
            "user_display_name",
            "user_bio",
            "user_location",
            "user_streaming_enabled"
        ] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
