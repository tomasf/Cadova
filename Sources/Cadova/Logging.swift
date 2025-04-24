import Foundation
import Logging

internal let logger: Logger = {
    LoggingSystem.bootstrap { label in
        let envLevel = ProcessInfo.processInfo.environment["CADOVA_LOG_LEVEL"]
            .flatMap { Logger.Level(rawValue: $0.lowercased()) }

        var handler = StreamLogHandler.standardOutput(label: label)
        handler.logLevel = envLevel ?? .info
        return handler
    }
    return Logger(label: "se.tomasf.Cadova")
}()
