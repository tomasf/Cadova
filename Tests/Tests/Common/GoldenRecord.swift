import Foundation
@testable import Cadova

struct GoldenRecord<D: Dimensionality>: Sendable, Hashable, Codable {
    let parts: [PartIdentifier: D.Node]

    init(result: BuildResult<D>) {
        if let result2D = result as? D2.BuildResult {
            parts = [.main: result2D.node as! D.Node]
        } else if let result3D = result as? D3.BuildResult {
            var parts = result.elements[PartCatalog.self].mergedOutputs.mapValues(\.node) as! [PartIdentifier: D.Node]
            parts[.main] = (result3D.node as! D.Node)
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

extension PartIdentifier {
    static let main = PartIdentifier(name: "Model", type: .solid, defaultMaterial: .plain(.white))
}
