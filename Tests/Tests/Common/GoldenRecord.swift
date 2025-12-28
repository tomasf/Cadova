import Foundation
@testable import Cadova

/// A simplified key for golden record comparison that ignores Part's UUID
private struct PartKey: Hashable, Codable {
    let name: String
    let semantic: PartSemantic

    init(_ part: Part) {
        self.name = part.name
        self.semantic = part.semantic
    }
}

struct GoldenRecord<D: Dimensionality>: Sendable, Hashable, Codable {
    private let parts: [PartKey: D.Node]

    init(result: BuildResult<D>) {
        if let result2D = result as? D2.BuildResult {
            parts = [PartKey(.main): result2D.node as! D.Node]
        } else if let result3D = result as? D3.BuildResult {
            var parts: [PartKey: D.Node] = result.elements[PartCatalog.self].mergedOutputs
                .reduce(into: [:]) { $0[PartKey($1.key)] = $1.value.node as? D.Node }
            parts[PartKey(.main)] = (result3D.node as! D.Node)
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

private extension Part {
    static let main = Part("Model", semantic: .solid)
}
