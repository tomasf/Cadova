import Foundation

/// Where a LiveLink listener (e.g. Cadova Viewer) binds its socket, and where a sender
/// (e.g. Cadova) looks for one. Both sides compute this independently; there's no
/// discovery or registration step.
internal enum LiveLinkEndpoint {
    /// A short, per-user path under `/tmp`, well clear of the ~104-byte limit on Unix
    /// domain socket paths (`sockaddr_un.sun_path`). Deliberately not under
    /// `~/Library/Application Support` or `NSTemporaryDirectory()`, either of which can
    /// push a real username or a per-launch random directory close to that limit.
    static var socketPath: String {
        "/tmp/cadova-livelink-\(ProcessInfo.processInfo.userName).sock"
    }
}
