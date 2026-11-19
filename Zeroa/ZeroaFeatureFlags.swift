import Foundation

/// Ship gates for App Store. Flip on when a feature is ready for reviewers.
enum ZeroaFeatureFlags {
    /// Switchboard / Hybrid Messaging (needs live HTTPS relay).
    static let switchboardEnabled = false
    /// AI / Nova / xAI surfaces (consent + network).
    static let aiFeaturesEnabled = false
}
