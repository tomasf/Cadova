import Foundation

internal struct Logger: Sendable {
    enum Level: Int, Comparable, Sendable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3

        static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    struct Message: ExpressibleByStringInterpolation, ExpressibleByStringLiteral {
        let value: String

        init(stringLiteral value: String) {
            self.value = value
        }

        init(stringInterpolation: DefaultStringInterpolation) {
            self.value = String(stringInterpolation: stringInterpolation)
        }
    }

    static let minimumLevel: Level = {
        if let envLevel = ProcessInfo.processInfo.environment["CADOVA_LOG_LEVEL"]?.lowercased() {
            switch envLevel {
            case "debug": return .debug
            case "info": return .info
            case "warning": return .warning
            case "error": return .error
            default: return .info
            }
        }
        return .info
    }()

    func debug(_ message: @autoclosure () -> Message) {
        log(.debug, message())
    }

    func info(_ message: @autoclosure () -> Message) {
        log(.info, message())
    }

    func warning(_ message: @autoclosure () -> Message) {
        log(.warning, message())
    }

    func error(_ message: @autoclosure () -> Message) {
        log(.error, message())
    }

    private func log(_ level: Level, _ message: Message) {
        guard level >= Self.minimumLevel else { return }
        let prefix: String
        switch level {
        case .debug: prefix = "[DEBUG]"
        case .info: prefix = "[INFO]"
        case .warning: prefix = "[WARNING]"
        case .error: prefix = "[ERROR]"
        }
        print("\(prefix) \(message.value)")
    }
}

internal let logger = Logger()
