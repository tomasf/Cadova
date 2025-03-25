import Foundation

protocol OutputDataProvider {
    func generateOutput() throws -> Data
    func writeOutput(to url: URL) throws
    var fileExtension: String { get }
}

extension OutputDataProvider {
    func writeOutput(to url: URL) throws {
        try generateOutput().write(to: url)
    }
}
