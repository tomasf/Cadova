import Foundation

internal struct PartCatalog: ResultElement {
    var parts: [Part: [BuildResult<D3>]]

    init(parts: [Part: [BuildResult<D3>]]) {
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

    mutating func add(result: BuildResult<D3>, to part: Part) {
        parts[part, default: []].append(result)
    }

    mutating func detach(_ part: Part) -> BuildResult<D3>? {
        guard let results = parts.removeValue(forKey: part) else {
            return nil
        }
        return BuildResult<D3>(combining: results, operationType: .union)
    }

    var mergedOutputs: [Part: BuildResult<D3>] {
        parts.mapValues { outputs in
            BuildResult<D3>(combining: outputs, operationType: .union)
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
