import Foundation

extension String {
    /// Redact a long identifier by keeping a prefix and suffix and inserting an ellipsis in the middle.
    /// Example: "ThGNWv22Mb89YwMKo8hAgTEL5ChWcnNuRJ" -> "ThGNWv…nNuRJ"
    func redactedAddress(prefix keepPrefix: Int = 6, suffix keepSuffix: Int = 5) -> String {
        guard count > keepPrefix + keepSuffix else { return self }
        let head = self.prefix(keepPrefix)
        let tail = self.suffix(keepSuffix)
        return head + "…" + tail
    }
}


