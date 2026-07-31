import Foundation

protocol OutputDataProvider {
    func generateOutput(context: EvaluationContext) async throws -> Data
    func writeOutput(to url: URL, context: EvaluationContext) async throws
    var fileExtension: String { get }
}

extension OutputDataProvider {
    func writeOutput(to url: URL, context: EvaluationContext) async throws {
        try await generateOutput(context: context).write(to: url)
    }
}
