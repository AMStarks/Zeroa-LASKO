import Foundation

enum LogLevel: String { case debug, info, warn, error }

struct Log {
    static var isEnabled = true
    static func debug(_ message: @autoclosure () -> String) { write(.debug, message()) }
    static func info(_ message: @autoclosure () -> String)  { write(.info,  message()) }
    static func warn(_ message: @autoclosure () -> String)  { write(.warn,  message()) }
    static func error(_ message: @autoclosure () -> String) { write(.error, message()) }

    private static func write(_ level: LogLevel, _ text: String) {
        #if DEBUG
        if isEnabled { print("[\(level.rawValue.uppercased())] \(text)") }
        #endif
    }
}

extension String {
    func redactedAddress() -> String { count > 10 ? prefix(6) + "…" + suffix(4) : self }
}
