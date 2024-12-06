#if !os(macOS) && !os(Windows)
import Foundation

// For other platforms, we look in PATH

internal extension OpenSCADExport {
    static func findExecutableAutomatically() -> URL? {
        guard let path = ProcessInfo.processInfo.environment["PATH"] else { return nil }

        let possibleExecutables = path.split(separator: ":").map {
            URL(filePath: String($0), directoryHint: .isDirectory).appending(component: "openscad")
        }

        let fileManager = FileManager()
        return possibleExecutables.first { fileManager.fileExists(atPath: $0.path()) }
    }
}

#endif
