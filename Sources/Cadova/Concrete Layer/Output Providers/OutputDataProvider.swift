import Foundation

protocol OutputDataProvider: Sendable {
    func generateOutput(context: EvaluationContext) async throws -> Data
    func writeOutput(to url: URL, context: EvaluationContext) async throws

    /// Pushes this model's data to any locally-listening LiveLink consumer (e.g. Cadova
    /// Viewer), bypassing the format-specific encoding `generateOutput` performs. Best-effort:
    /// implementations must never throw out of this method. The default does nothing, which is
    /// appropriate for formats with no 3D mesh worth short-circuiting a reload for.
    ///
    /// Returns whether the data actually reached a listener.
    @discardableResult
    func pushToLiveLink(destination url: URL, context: EvaluationContext) async -> Bool

    /// A cheap, synchronous best guess at whether `pushToLiveLink` would succeed, without doing
    /// any of its real work — lets a caller schedule other work (e.g. a write's priority) around
    /// the push before it's run. Best-effort: the real push can still turn out differently.
    func isLikelyToReachLiveLinkListener(destination url: URL) -> Bool

    var fileExtension: String { get }
}

extension OutputDataProvider {
    func writeOutput(to url: URL, context: EvaluationContext) async throws {
        let data = try await generateOutput(context: context)
        try FileManager().publishFile(at: url) { try data.write(to: $0) }
    }

    func pushToLiveLink(destination url: URL, context: EvaluationContext) async -> Bool { false }
    func isLikelyToReachLiveLinkListener(destination url: URL) -> Bool { false }
}

internal extension FileManager {
    /// Writes a file into place without ever leaving the destination half-written.
    ///
    /// `write` is handed a temporary URL beside `url`, and only once it has returned does the
    /// finished file take the destination's place, in a single move. Writing straight to the
    /// destination would truncate it the moment the file is opened, so anything going wrong after
    /// that — a full disk, an I/O error, a process killed partway through a large export — would
    /// leave a truncated file where a known-good model used to be. Here, a failure at any point
    /// leaves the previous file exactly as it was.
    ///
    /// The destination's existing metadata and permissions are preserved. The temporary file is
    /// removed whenever the write throws; a process killed outright leaves it behind, since nothing
    /// runs at that point, so it is named as a dotfile beside the destination. Replacing a symbolic
    /// link replaces the link rather than following it to its target.
    func publishFile(at url: URL, writingWith write: (URL) throws -> Void) throws {
        let directory = url.deletingLastPathComponent()
        let temporaryURL = directory.appendingPathComponent(
            ".\(url.lastPathComponent).\(UUID().uuidString).partial",
            isDirectory: false
        )

        do {
            try write(temporaryURL)

            // Asking whether the destination exists and then acting on the answer leaves a window
            // in which it can appear, so try the move and let the failure say so instead.
            do {
                try moveItem(at: temporaryURL, to: url)
            } catch CocoaError.fileWriteFileExists {
                _ = try replaceItemAt(url, withItemAt: temporaryURL)
            }
        } catch {
            try? removeItem(at: temporaryURL)
            throw error
        }
    }
}
