import Foundation

/// Runtime configuration for the live link, the local IPC push used to short-circuit the
/// disk round trip between Cadova and a listening consumer (e.g. Cadova Viewer).
internal enum LiveLinkSettings {
    /// Set `CADOVA_LIVELINK_DISABLED=true` to suppress pushing model data to local
    /// live link listeners. Disk output (3MF/STL/SVG) is unaffected either way.
    nonisolated(unsafe) static var isDisabled = defaultIsDisabled()

    static func defaultIsDisabled(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        switch environment["CADOVA_LIVELINK_DISABLED"]?.lowercased() {
        case "1", "true", "yes", "on": true
        default: false
        }
    }
}
