import Foundation

protocol OutputDataProvider {
    func generateOutput() throws -> Data
    var fileExtension: String { get }
}
