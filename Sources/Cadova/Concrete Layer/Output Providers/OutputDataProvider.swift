import Foundation
import CadovaLiveLink

protocol OutputDataProvider {
    func generateOutput(context: EvaluationContext) async throws -> Data
    func writeOutput(to url: URL, context: EvaluationContext) async throws

    /// Pushes this model's data to any locally-listening LiveLink consumer (e.g. Cadova
    /// Viewer), bypassing the format-specific encoding `generateOutput` performs. Best-effort:
    /// implementations must never throw out of this method. The default does nothing, which is
    /// appropriate for formats with no 3D mesh worth short-circuiting a reload for.
    func pushToLiveLink(destination url: URL, context: EvaluationContext) async
    var fileExtension: String { get }
}

extension OutputDataProvider {
    func writeOutput(to url: URL, context: EvaluationContext) async throws {
        try await generateOutput(context: context).write(to: url)
    }

    func pushToLiveLink(destination url: URL, context: EvaluationContext) async {}
}
