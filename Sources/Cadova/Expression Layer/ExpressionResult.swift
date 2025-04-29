import Foundation
import Manifold3D

public struct ExpressionResult<D: Dimensionality>: Sendable {
    internal let primitive: D.Primitive
    internal let materialMapping: [Material?: Set<Manifold.OriginalID>]

    private init(primitive: D.Primitive, materialMapping: [Material?: Set<Manifold.OriginalID>]) {
        self.primitive = primitive
        self.materialMapping = materialMapping
    }

    internal init(_ primitive: CrossSection) where D == D2 {
        self.init(primitive: primitive, materialMapping: [:])
    }

    internal init(original: D.Primitive) {
        if var geometry = original as? Manifold {
            var originalID = geometry.originalID
            if originalID == nil {
                logger.warning("Expected original geometry, but got geometry without an original ID. Assigning one.")
                geometry = geometry.asOriginal()
                originalID = geometry.originalID
            }

            self.primitive = geometry as! D.Primitive

            if let originalID {
                materialMapping = [nil: [originalID]]
            } else {
                logger.error("Failed to assign an original ID to geometry")
                materialMapping = [:]
            }
        } else {
            self.primitive = original
            materialMapping = [:]
        }
    }

    internal init(product: Manifold, results: [Self]) where D == D3 {
        self.primitive = product

        var merged: [Material?: Set<Manifold.OriginalID>] = [:]
        for result in results {
            merged.merge(result.materialMapping) { $0.union($1) }
        }

        self.materialMapping = merged
    }

    func modified(_ action: (D.Primitive) -> D.Primitive) -> Self {
        .init(primitive: action(primitive), materialMapping: materialMapping)
    }

    func applyingMaterial(_ application: GeometryExpression3D.MaterialApplication) -> Self where D == D3 {
        if application.behavior == .replace {
            let original = primitive.asOriginal()
            let originalID = original.originalID
            guard let originalID else {
                logger.error("Failed to assign an original ID to geometry")
                return self
            }
            return .init(primitive: original, materialMapping: [application.material: [originalID]])

        } else {
            var mapping = materialMapping
            if let plain = mapping[nil] {
                mapping[application.material, default: []].formUnion(plain)
                mapping[nil] = nil
            }
            return .init(primitive: primitive, materialMapping: mapping)
        }
    }

    internal static var empty: Self { .init(primitive: .empty, materialMapping: [:]) }

    internal var materialsByOriginalID: [Manifold.OriginalID: Material] {
        Dictionary(materialMapping.compactMap { material, IDs -> [(Manifold.OriginalID, Material)]? in
            guard let material else { return nil }
            return IDs.map { ($0, material) }
        }.flatMap { $0 }, uniquingKeysWith: { $1 })
    }
}
