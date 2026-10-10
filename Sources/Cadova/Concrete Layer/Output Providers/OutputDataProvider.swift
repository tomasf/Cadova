import Foundation

protocol OutputDataProvider: Sendable {
    /// Evaluates the geometry the output is made from, so a build can time evaluation, usually its
    /// longest step, on its own. The results stay in the context's cache, where generating the output
    /// and pushing it to LiveLink find them afterwards.
    func evaluate(context: EvaluationContext) async throws

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
        // Written beside the destination and moved into place once complete, so a write that fails
        // partway through, on a full disk say, leaves the previous file untouched rather than
        // truncated.
        // WASI has no temporary files to write through, so there the file is written in place.
        #if os(WASI)
        try await generateOutput(context: context).write(to: url)
        #else
        try await generateOutput(context: context).write(to: url, options: .atomic)
        #endif
    }

    /// Nothing to evaluate up front: the output does its own work when it's generated
    func evaluate(context: EvaluationContext) async throws {}
    func pushToLiveLink(destination url: URL, context: EvaluationContext) async -> Bool { false }
    func isLikelyToReachLiveLinkListener(destination url: URL) -> Bool { false }
}
