import Testing
import Foundation
@testable import Cadova

extension URL {
    init(goldenFileNamed name: String, extension fileExtension: String) throws {
        guard let url = Bundle.module.url(forResource: name, withExtension: fileExtension, subdirectory: "golden") else {
            fatalError("Golden file \(name).\(fileExtension) not found")
        }
        self = url
    }
}

extension EvaluationContext {
    func concrete<D: Dimensionality>(for geometry: D.Geometry, in environment: EnvironmentValues = .defaultEnvironment) async throws -> D.Concrete {
        try await self.result(for: geometry, in: environment).concrete
    }
}
