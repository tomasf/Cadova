import Foundation

/// Runtime settings that control library-wide behavior.
///
/// Each setting can be read and changed at any time. Settings backed by an environment
/// variable are seeded from it at process startup, and can be overridden afterward.
public enum Settings {
    /// The minimum severity of messages Cadova logs.
    ///
    /// Seeded from the `CADOVA_LOG_LEVEL` environment variable (`debug`, `info`,
    /// `warning`, or `error`); defaults to `.info` if the variable is unset or unrecognized.
    nonisolated(unsafe) public static var logLevel: LogLevel = {
        switch ProcessInfo.processInfo.environment["CADOVA_LOG_LEVEL"]?.lowercased() {
        case "debug": .debug
        case "warning": .warning
        case "error": .error
        default: .info
        }
    }()

    /// Whether generated output files are revealed in Finder, File Explorer, or the
    /// equivalent file manager on other platforms after a model or project is built.
    nonisolated(unsafe) public static var isFileRevealingEnabled = true

    /// The severity of a log message.
    public enum LogLevel: Int, Comparable, Sendable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}
