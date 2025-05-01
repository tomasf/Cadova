import Foundation

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

public enum PartType: String, Hashable, Sendable, Codable {
    case solid
    case visual
}

internal struct PartCatalog: ResultElement {
    var parts: [PartIdentifier: [D3.BuildResult]]

    init(parts: [PartIdentifier: [D3.BuildResult]]) {
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

    mutating func add(part: D3.BuildResult, to identifier: PartIdentifier) {
        parts[identifier, default: []].append(part)
    }

    var mergedOutputs: [PartIdentifier: D3.BuildResult] {
        parts.mapValues { outputs in
            D3.BuildResult(combining: outputs, operationType: .union)
        }
    }

    func modifyingExpressions(_ modifier: (D3.Node) -> D3.Node) -> Self {
        .init(parts: parts.mapValues {
            $0.map { $0.replacing(node: modifier($0.node)) }
        })
    }

    func applyingTransform(_ transform: AffineTransform3D) -> Self {
        modifyingExpressions { .transform($0, transform: transform) }
    }
}
