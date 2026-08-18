import Foundation

/// Pushes a `LiveLinkMessage` to whatever is listening at the well-known LiveLink socket
/// (e.g. Cadova Viewer's `LiveLinkServer`), if anything is. Best-effort and macOS-only:
/// on any other platform, or when nothing is listening, `push` returns quickly without
/// doing anything.
public enum LiveLinkClient {
    public static func push(_ message: LiveLinkMessage) async throws {
        guard !LiveLinkSettings.isDisabled else { return }
        guard FileManager.default.fileExists(atPath: LiveLinkEndpoint.socketPath) else { return }
        try await send(message)
    }
}
