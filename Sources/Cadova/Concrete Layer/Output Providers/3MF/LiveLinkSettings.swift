import Foundation

/// Runtime configuration for the live link, the local IPC push used to short-circuit the
/// disk round trip between Cadova and a listening consumer (e.g. Cadova Viewer).
internal enum LiveLinkSettings {
    /// Set `CADOVA_LIVELINK_DISABLED=true` to suppress pushing model data to local
    /// live link listeners. Disk output (3MF/STL/SVG) is unaffected either way.
    nonisolated(unsafe) static var isDisabled = defaultIsDisabled()

    static func defaultIsDisabled(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        boolean(environment["CADOVA_LIVELINK_DISABLED"])
    }

    /// Set `CADOVA_LIVELINK_ONLY=true` to skip writing the model file when the push
    /// actually reached a listener that is watching that path. Intended for an interactive
    /// edit loop, where the file is written on every save and never read: the viewer already
    /// has the mesh over the socket before the archive is even generated.
    ///
    /// Deliberately narrow. If the live link is disabled, no host is listening, the host isn't
    /// watching this path, or the push fails for any reason, the file is written exactly as
    /// before — so the output can only be missing in the one case where something else
    /// demonstrably already has the geometry.
    nonisolated(unsafe) static var isLiveLinkOnly = defaultIsLiveLinkOnly()

    static func defaultIsLiveLinkOnly(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        boolean(environment["CADOVA_LIVELINK_ONLY"])
    }

    private static func boolean(_ value: String?) -> Bool {
        switch value?.lowercased() {
        case "1", "true", "yes", "on": true
        default: false
        }
    }
}
