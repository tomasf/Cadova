import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Where a LiveLink listener (e.g. Cadova Viewer) binds its socket, and where a sender
/// (e.g. Cadova) looks for one. Both sides compute this independently; there's no
/// discovery or registration step.
public enum LiveLinkEndpoint {
    /// Cadova Viewer is App-Sandboxed, so it can't create a socket file under `/tmp` — its socket
    /// necessarily lives inside its own container (`~/Library/Containers/<bundle-id>/Data/tmp/`).
    /// This is that bundle identifier; there's no bundle-agnostic path both sides could reach instead.
    private static let viewerBundleIdentifier = "se.tomasf.CadovaViewer"

    public static var socketPath: String {
        realHomeDirectory + "/Library/Containers/\(viewerBundleIdentifier)/Data/tmp/cadova-livelink.sock"
    }

    /// The user's real home directory. Needed instead of `NSHomeDirectory()`/`FileManager.homeDirectoryForCurrentUser`,
    /// which App Sandbox redirects to the calling app's own container when read from inside a
    /// sandboxed process — reading straight from the user database instead resolves to the same
    /// real path (`/Users/<name>`) whether this runs from sandboxed Cadova Viewer or unsandboxed
    /// Cadova, which is what lets both sides agree on the same container-relative socket path.
    private static var realHomeDirectory: String {
        #if canImport(Darwin)
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        #endif
        return NSHomeDirectory()
    }
}
