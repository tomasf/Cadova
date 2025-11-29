import Foundation

internal struct PartIdentifier: Hashable, Sendable, Codable {
    let name: String
    let type: PartSemantic
    let defaultMaterial: Material

    static let highlight = PartIdentifier(name: "Highlighted", type: .visual, defaultMaterial: .highlightedGeometry)
    static let background = PartIdentifier(name: "Background", type: .context, defaultMaterial: .backgroundGeometry)

    static func named(_ name: String, type: PartSemantic) -> PartIdentifier {
        .init(name: name, type: type, defaultMaterial: .plain(.white))
    }
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

    mutating func detachPart(named name: String, ofType semantic: PartSemantic) -> D3.BuildResult? {
        guard let identifier = parts.keys.first(where: { $0.name == name && $0.type == semantic }) else {
            return nil
        }
        let mergedResults = D3.BuildResult(combining: parts[identifier]!, operationType: .union)
        parts[identifier] = nil
        return mergedResults
    }

    var mergedOutputs: [PartIdentifier: D3.BuildResult] {
        parts.mapValues { outputs in
            D3.BuildResult(combining: outputs, operationType: .union)
        }
    }

    func modifyingNodes(_ modifier: (D3.Node) -> D3.Node) -> Self {
        .init(parts: parts.mapValues {
            $0.map { $0.replacing(node: modifier($0.node)) }
        })
    }

    func applyingTransform(_ transform: Transform3D) -> Self {
        guard !parts.isEmpty else { return self }
        return modifyingNodes { .transform($0, transform: transform) }
    }
}
