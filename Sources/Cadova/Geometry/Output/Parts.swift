import Foundation

internal struct PartCatalog: ResultElement {
    var parts: [PartIdentifier: [GeometryResult3D]]

    init(parts: [PartIdentifier: [GeometryResult3D]]) {
        self.parts = parts
    }

    init() {
        self.init(parts: [:])
    }

    func adding(part: GeometryResult3D, to identifier: PartIdentifier) -> PartCatalog {
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

    var mergedOutputs: [PartIdentifier: GeometryResult3D] {
        parts.mapValues { outputs in
            GeometryResult3D(primitive: .boolean(.union, with: outputs.map(\.primitive)), elements: .init(combining: outputs.map(\.elements), operation: .union))
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

public enum PartType: Hashable {
    case solid
    case visual
}

internal struct PartIdentifier: Hashable {
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
