import Foundation
import Manifold3D

public struct EvaluationResult<D: Dimensionality>: Sendable {
    internal let concrete: D.Concrete
    internal let materialMapping: [Manifold.OriginalID: Material]

    private init(concrete: D.Concrete, materialMapping: [Manifold.OriginalID: Material]) {
        self.concrete = concrete
        self.materialMapping = materialMapping
    }

    internal init(_ concrete: D.Concrete) {
        if let manifold = concrete as? Manifold, let error = manifold.status {
            print(error)
        }
        self.init(concrete: concrete, materialMapping: [:])
    }

    internal init(_ concrete: D.Concrete, material: Material) where D == D3 {
        let geometry = concrete.asOriginal()
        guard let originalID = geometry.originalID else {
            logger.error("Failed to assign an original ID to geometry")
            self = .init(concrete)
            return
        }

        self.init(concrete: geometry, materialMapping: [originalID: material])
    }

    internal init(product: D.Concrete, results: [Self]) {
        self.concrete = product

        var merged: [Manifold.OriginalID: Material] = [:]
        for result in results {
            merged.merge(result.materialMapping) { $1 }
        }

        self.materialMapping = merged
    }

    func modified(_ action: (D.Concrete) throws -> D.Concrete) rethrows -> Self {
        .init(concrete: try action(concrete), materialMapping: materialMapping)
    }

    func applyingMaterial(_ material: Material) -> Self where D == D3 {
        .init(concrete, material: material)
    }

    internal static var empty: Self { .init(concrete: .empty, materialMapping: [:]) }
}
