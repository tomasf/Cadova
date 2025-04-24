import Foundation

internal struct PartCatalog: ResultElement {
    var parts: [PartIdentifier: [GeometryResult3D]]

    init(parts: [PartIdentifier: [GeometryResult3D]]) {
        self.parts = parts
    }

    init() {
        self.init(parts: [:])
    }

    init(combining catalogs: [PartCatalog]) {
        self.init(parts: catalogs.reduce(into: [:]) { result, catalog in
            result.merge(catalog.parts, uniquingKeysWith: +)
        })
    }

    mutating func add(part: GeometryResult3D, to identifier: PartIdentifier) {
        parts[identifier, default: []].append(part)
    }

    var mergedOutputs: [PartIdentifier: GeometryResult3D] {
        parts.mapValues { outputs in
            GeometryResult3D(combining: outputs, operationType: .union)
        }
    }

    func modifyingExpressions(_ modifier: (D3.Expression) -> D3.Expression) -> Self {
        .init(parts: parts.mapValues {
            $0.map { $0.replacing(expression: modifier($0.expression)) }
        })
    }

    func applyingTransform(_ transform: AffineTransform3D) -> Self {
        modifyingExpressions { .transform($0, transform: transform) }
    }
}

public enum PartType: String, Hashable, Sendable, Codable {
    case solid
    case visual
}

internal struct PartIdentifier: Hashable, Sendable, Codable {
    let name: String
    let type: PartType
    let defaultMaterial: Material

    static var main: PartIdentifier { .init(name: "Model", type: .solid, defaultMaterial: .plain(.white)) }
    static var highlight: PartIdentifier { .init(name: "Highlighted", type: .visual, defaultMaterial: .plain(.red, alpha: 0.2)) }
    static var background: PartIdentifier { .init(name: "Background", type: .visual, defaultMaterial: .plain(.gray, alpha: 0.1)) }

    static func named(_ name: String, type: PartType) -> PartIdentifier {
        .init(name: name, type: type, defaultMaterial: .plain(.white))
    }
}
