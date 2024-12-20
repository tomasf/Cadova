import Foundation

struct PartCatalog: ResultElement {
    var parts: [PartIdentifier: [Output3D]]

    init(parts: [PartIdentifier: [Output3D]]) {
        self.parts = parts
    }

    init() {
        self.init(parts: [:])
    }

    func adding(part: Output3D, to identifier: PartIdentifier) -> PartCatalog {
        Self.combining(catalogs: [self, .init(parts: [identifier: [part]])])
    }

    static func combining(catalogs: [PartCatalog]) -> PartCatalog {
        .init(parts: catalogs.reduce(into: [:]) { result, catalog in
            result.merge(catalog.parts, uniquingKeysWith: +)
        })
    }

    static func combine(elements: [PartCatalog], for operation: GeometryCombination) -> PartCatalog? {
        .combining(catalogs: elements)
    }

    var mergedOutputs: [PartIdentifier: Output3D] {
        parts.mapValues { outputs in
            Output3D(manifold: .boolean(.union, with: outputs.map(\.manifold)), elements: .init(combining: outputs.map(\.elements), operation: .union))
        }
    }
}

internal enum PartIdentifier: Hashable {
    case main
    case highlight
    case background
    case named (String)

    var name: String {
        switch self {
        case .main: return "main"
        case .highlight: return "highlight"
        case .background: return "background"
        case .named(let name): return name
        }
    }
}
