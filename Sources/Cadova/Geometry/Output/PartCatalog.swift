import Foundation

internal struct PartCatalog: ResultElement {
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
            Output3D(primitive: .boolean(.union, with: outputs.map(\.primitive)), elements: .init(combining: outputs.map(\.elements), operation: .union))
        }
    }

    func modifyingPrimitives(_ modifier: (D3.Primitive) -> D3.Primitive) -> Self {
        .init(parts: parts.mapValues {
            $0.map { $0.modifyingPrimitive(modifier)}
        })
    }

    func applyingTransform(_ transform: AffineTransform3D) -> Self {
        modifyingPrimitives { $0.transform(transform) }
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
        case .named (let name): return name
        }
    }

    var defaultMaterial: Material {
        switch self {
        case .main: .init(baseColor: .white)
        case .highlight: .init(baseColor: .red.withAlphaComponent(0.2))
        case .background: .init(baseColor: .gray.withAlphaComponent(0.1))
        case .named: .init(baseColor: .white)
        }
    }
}
