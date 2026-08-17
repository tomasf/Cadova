import Foundation

internal struct Logger: Sendable {
    struct Message: ExpressibleByStringInterpolation, ExpressibleByStringLiteral {
        let value: String

        init(stringLiteral value: String) {
            self.value = value
        }

        init(stringInterpolation: DefaultStringInterpolation) {
            self.value = String(stringInterpolation: stringInterpolation)
        }
    }

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

    private func log(_ level: Settings.LogLevel, _ message: Message) {
        guard level >= Settings.logLevel else { return }
        let timestamp = Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: true))
        let prefix: String
        switch level {
        case .debug: prefix = "[DEBUG]"
        case .info: prefix = "[INFO]"
        case .warning: prefix = "⚠️ [WARNING]"
        case .error: prefix = "🛑 [ERROR]"
        }
        print("\(timestamp) \(prefix) \(message.value)")
    }
}

internal let logger = Logger()
