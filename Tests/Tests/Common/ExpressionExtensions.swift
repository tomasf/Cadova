import Testing
import Foundation
@testable import Cadova

struct MissingGoldenFile: Error, CustomStringConvertible {
    let name: String
    let fileExtension: String

    var description: String {
        "Golden file \(name).\(fileExtension) not found in the test bundle's golden directory"
    }
}

extension URL {
    init(goldenFileNamed name: String, extension fileExtension: String) throws {
        guard let url = Bundle.module.url(forResource: name, withExtension: fileExtension, subdirectory: "golden") else {
            throw MissingGoldenFile(name: name, fileExtension: fileExtension)
        }
        self = url
    }
}

extension _EvaluationContext {
    func concrete<D: Dimensionality>(for geometry: D.Geometry, in environment: EnvironmentValues = .defaultEnvironment) async throws -> D.Concrete {
        try await self.result(for: geometry, in: environment).concrete
    }
}
