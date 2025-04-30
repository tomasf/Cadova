import Foundation
import Manifold3D

public struct ExpressionResult<D: Dimensionality>: Sendable {
    internal let primitive: D.Primitive
    internal let materialMapping: [Manifold.OriginalID: Material]

    private init(primitive: D.Primitive, materialMapping: [Manifold.OriginalID: Material]) {
        self.primitive = primitive
        self.materialMapping = materialMapping
    }

    internal init(_ primitive: D.Primitive) {
        self.init(primitive: primitive, materialMapping: [:])
    }

    internal init(_ primitive: D.Primitive, material: Material) where D == D3 {
        let geometry = primitive.asOriginal()
        guard let originalID = geometry.originalID else {
            logger.error("Failed to assign an original ID to geometry")
            self = .init(primitive)
            return
        }

        self.init(primitive: geometry, materialMapping: [originalID: material])
    }

    internal init(product: Manifold, results: [Self]) where D == D3 {
        self.primitive = product

        var merged: [Manifold.OriginalID: Material] = [:]
        for result in results {
            merged.merge(result.materialMapping) { $1 }
        }

        self.materialMapping = merged
    }

    func modified(_ action: (D.Primitive) -> D.Primitive) -> Self {
        .init(primitive: action(primitive), materialMapping: materialMapping)
    }

    func applyingMaterial(_ material: Material) -> Self where D == D3 {
        .init(primitive, material: material)
    }

    internal static var empty: Self { .init(primitive: .empty, materialMapping: [:]) }
}
