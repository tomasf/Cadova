#if os(macOS)
import Foundation
import AppKit

// On macOS, try to find OpenSCAD with Launch Services

internal extension OpenSCADExport {
    static func findExecutableAutomatically() -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.openscad.OpenSCAD").flatMap {
            Bundle(url: $0)?.executableURL
        }
    }
}

#endif
