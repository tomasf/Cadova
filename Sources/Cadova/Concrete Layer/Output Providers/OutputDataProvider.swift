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
        try await generateOutput(context: context).write(to: url)
    }

    func pushToLiveLink(destination url: URL, context: EvaluationContext) async -> Bool { false }
    func isLikelyToReachLiveLinkListener(destination url: URL) -> Bool { false }
}
