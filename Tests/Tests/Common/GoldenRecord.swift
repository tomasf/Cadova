import Foundation
@testable import Cadova

struct GoldenRecord<D: Dimensionality>: Sendable, Hashable, Codable {
    let parts: [PartIdentifier: D.Expression]

    init(result: GeometryResult<D>) {
        if let result2D = result as? GeometryResult2D {
            parts = [.main: result2D.expression as! D.Expression]
        } else if let result3D = result as? GeometryResult3D {
            var parts = result.elements[PartCatalog.self].mergedOutputs.mapValues(\.expression) as! [PartIdentifier: D.Expression]
            parts[.main] = (result3D.expression as! D.Expression)
            self.parts = parts
        } else {
            fatalError("Invalid geometry type")
        }
    }

    init(url: URL) throws {
        self = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }

    func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(self).write(to: url)
    }
}
