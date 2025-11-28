import Foundation
import Manifold3D

public struct EvaluationResult<D: Dimensionality>: Sendable {
    internal let parts: [D.Concrete]
    internal let materialMapping: [Manifold.OriginalID: Material]

    internal var concrete: D.Concrete {
        guard parts.count == 1 else {
            assertionFailure(".concrete was used with multipart EvaluationResult")
            return .boolean(.union, with: parts)
        }
        return parts[0]
    }

    private init(parts: [D.Concrete], materialMapping: [Manifold.OriginalID: Material]) throws {
        if let manifold = parts as? [Manifold], let error = manifold.compactMap(\.status).first {
            throw error
        }

        self.parts = parts
        self.materialMapping = materialMapping
    }

    private init(concrete: D.Concrete, materialMapping: [Manifold.OriginalID: Material]) throws {
        try self.init(parts: [concrete], materialMapping: materialMapping)
    }

    internal init(_ concrete: D.Concrete) throws {
        if let manifold = concrete as? Manifold, let error = manifold.status {
            print(error)
        }
        try self.init(concrete: concrete, materialMapping: [:])
    }

    internal init(_ concrete: D.Concrete, material: Material) throws where D == D3 {
        let geometry = concrete.asOriginal()
        guard let originalID = geometry.originalID else {
            logger.error("Failed to assign an original ID to geometry")
            self = try .init(concrete)
            return
        }

        try self.init(concrete: geometry, materialMapping: [originalID: material])
    }

    internal init(product: D.Concrete, results: [Self]) throws {
        var merged: [Manifold.OriginalID: Material] = [:]
        for result in results {
            merged.merge(result.materialMapping) { $1 }
        }

        try self.init(concrete: product, materialMapping: merged)
    }

    func modified(_ action: (D.Concrete) throws -> D.Concrete) throws -> Self {
        try .init(concrete: try action(concrete), materialMapping: materialMapping)
    }

    func modified(_ action: (D.Concrete) throws -> [D.Concrete]) throws -> Self {
        try .init(parts: try action(concrete), materialMapping: materialMapping)
    }

    func modified(_ action: ([D.Concrete]) throws -> D.Concrete) throws -> Self {
        try .init(concrete: try action(parts), materialMapping: materialMapping)
    }

    func applyingMaterial(_ material: Material) -> Self where D == D3 {
        try! .init(concrete, material: material)
    }

    func baked() throws -> Self {
        try Self(parts: parts.map { $0.baked() }, materialMapping: materialMapping)
    }

    internal static var empty: Self { try! .init(concrete: .empty, materialMapping: [:]) }
}
