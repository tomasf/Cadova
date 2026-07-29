import Foundation

internal struct PartCatalog: ResultElement {
    var parts: [Part: [D3._BuildResult]]

    init(parts: [Part: [D3._BuildResult]]) {
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

    mutating func add(result: D3._BuildResult, to part: Part) {
        parts[part, default: []].append(result)
    }

    mutating func detach(_ part: Part) -> D3._BuildResult? {
        guard let results = parts.removeValue(forKey: part) else {
            return nil
        }
        return D3._BuildResult(combining: results, operationType: .union)
    }

    var mergedOutputs: [Part: D3._BuildResult] {
        parts.mapValues { outputs in
            D3._BuildResult(combining: outputs, operationType: .union)
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
