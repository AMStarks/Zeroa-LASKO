import Foundation
import Combine

/// One-time / revocable consent for sharing prompts with xAI (`api.x.ai`).
@MainActor
final class AIConsentManager: ObservableObject {
    static let shared = AIConsentManager()

    private let grantedKey = "zeroa.ai.xai.consent.granted"
    private let decidedKey = "zeroa.ai.xai.consent.decided"

    @Published private(set) var hasGrantedConsent: Bool
    @Published private(set) var hasMadeChoice: Bool

    private init() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-UI_TEST_FORCE_AI_CONSENT_PROMPT") {
            // UI tests: start undecided so Allow / Not now can be exercised.
            hasGrantedConsent = false
            hasMadeChoice = false
            return
        }
        if ZeroaDemoMode.isEnabled {
            // Screenshots / App Review demo: treat consent as granted so AI UI is not blocked.
            hasGrantedConsent = true
            hasMadeChoice = true
            return
        }
        hasGrantedConsent = UserDefaults.standard.bool(forKey: grantedKey)
        hasMadeChoice = UserDefaults.standard.bool(forKey: decidedKey)
    }

    /// Used by UI tests to reset in-memory consent without relaunching UserDefaults state.
    func resetForUITestPrompt() {
        hasGrantedConsent = false
        hasMadeChoice = false
    }

    var needsConsentPrompt: Bool {
        !hasMadeChoice
    }

    var canUseAI: Bool {
        hasGrantedConsent
    }

    func allow() {
        hasGrantedConsent = true
        hasMadeChoice = true
        persist()
    }

    func decline() {
        hasGrantedConsent = false
        hasMadeChoice = true
        persist()
    }

    func setConsentEnabled(_ enabled: Bool) {
        hasGrantedConsent = enabled
        hasMadeChoice = true
        persist()
    }

    private func persist() {
        guard !ZeroaDemoMode.isEnabled else { return }
        UserDefaults.standard.set(hasGrantedConsent, forKey: grantedKey)
        UserDefaults.standard.set(hasMadeChoice, forKey: decidedKey)
    }
}

enum AIConsentError: LocalizedError {
    case consentRequired
    case consentDeclined
    case containsSecrets

    var errorDescription: String? {
        switch self {
        case .consentRequired:
            return "Please allow AI data sharing before using AI features."
        case .consentDeclined:
            return "AI features are off. Enable “Share data with xAI” in Settings to continue."
        case .containsSecrets:
            return "For your security, wallet recovery phrases and private keys are never sent to AI."
        }
    }
}

enum AISecretGuard {
    /// Returns true if `text` appears to contain a seed phrase or private key that must not leave the device.
    static func containsSensitiveSecrets(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if let mnemonic = KeychainService.shared.read(key: "wallet_mnemonic"),
           !mnemonic.isEmpty,
           text.range(of: mnemonic, options: .caseInsensitive) != nil {
            return true
        }
        if let privateKey = KeychainService.shared.read(key: "wallet_private_key"),
           !privateKey.isEmpty,
           text.range(of: privateKey, options: .caseInsensitive) != nil {
            return true
        }

        // Standalone 64-char hex private-key shape.
        if let regex = try? NSRegularExpression(pattern: #"(?i)\b[0-9a-f]{64}\b"#),
           regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            return true
        }

        // Likely BIP39 seed: 12 / 15 / 18 / 21 / 24 space-separated words (letters only).
        let words = trimmed
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" })
            .map(String.init)
        let wordCounts: Set<Int> = [12, 15, 18, 21, 24]
        if wordCounts.contains(words.count),
           words.allSatisfy({ $0.count >= 3 && $0.unicodeScalars.allSatisfy(CharacterSet.letters.contains) }) {
            return true
        }

        return false
    }
}
