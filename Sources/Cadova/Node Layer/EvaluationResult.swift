import Foundation
import Manifold3D

internal struct EvaluationResult<D: Dimensionality>: Sendable {
    internal let parts: [D.Concrete]
    internal let materialMapping: [Manifold.OriginalID: Material]

    internal var concrete: D.Concrete {
        guard parts.count == 1 else {
            assertionFailure(".concrete was used with multipart EvaluationResult")
            return .boolean(.union, with: parts)
        }
        return parts[0]
    }

    // Results are validated as they're made, which means evaluating them. Manifold defers
    // transforms until something needs the mesh, and validating a transformed result would make a
    // transformed copy of every mesh up front, so those results aren't validated. A transform
    // can't introduce an error, and its input was validated when it was made, but validated()
    // still checks every result before output.
    internal init(unvalidatedParts parts: [D.Concrete], materialMapping: [Manifold.OriginalID: Material]) {
        self.parts = parts
        self.materialMapping = materialMapping
    }

    private init(parts: [D.Concrete], materialMapping: [Manifold.OriginalID: Material]) throws {
        self.init(unvalidatedParts: parts, materialMapping: materialMapping)
        _ = try validated()
    }

    internal init(concrete: D.Concrete, materialMapping: [Manifold.OriginalID: Material]) throws {
        try self.init(parts: [concrete], materialMapping: materialMapping)
    }

    internal init(_ concrete: D.Concrete) throws {
        if let manifold = concrete as? Manifold, let error = manifold.status {
            throw error
        }
        try self.init(concrete: concrete, materialMapping: [:])
    }

    internal init(_ concrete: D.Concrete, material: Material) throws where D == D3 {
        let geometry = concrete.asOriginal()
        guard let originalID = geometry.originalID else {
            ModelLogger.current.error("Failed to assign an original ID to geometry")
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

    /// Throws the error of any part that has one. This evaluates every part.
    func validated() throws -> Self {
        if let manifolds = parts as? [Manifold], let error = manifolds.compactMap(\.status).first {
            throw error
        }
        return self
    }

    /// This result, transformed. It isn't validated.
    func transformed(_ transform: D.Concrete.Transform) -> Self {
        .init(unvalidatedParts: [concrete.transform(transform)], materialMapping: materialMapping)
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

    func clearingMaterials() -> Self where D == D3 {
        .init(unvalidatedParts: parts, materialMapping: [:])
    }

    internal static var empty: Self { try! .init(concrete: .empty, materialMapping: [:]) }
}

internal extension EvaluationResult {
    /// Roughly how much memory the result takes up, in bytes, for limiting the size of the cache.
    ///
    /// A Manifold mesh (see Manifold's impl.h) keeps, per triangle, three 16-byte halfedges, a face
    /// normal (24 bytes) and a 16-byte reference to its original mesh, and a collision tree that
    /// adds about another 100 bytes. Per vertex, it keeps a position and a normal (24 bytes each),
    /// and 8 bytes for each extra property (`propertyCount` doesn't include the position). A
    /// cross-section keeps each of its points, with some overhead. Results that share a mesh are
    /// each counted in full. Measured against what the allocator holds, this comes within about
    /// 20% for small meshes and closer for large ones.
    var estimatedByteCount: Int {
        let materials = materialMapping.count * 64
        if let manifolds = parts as? [Manifold] {
            return manifolds.reduce(materials) { total, manifold in
                total + manifold.triangleCount * 190 + manifold.vertexCount * (48 + 8 * manifold.propertyCount)
            }
        } else if let crossSections = parts as? [CrossSection] {
            return crossSections.reduce(materials) { $0 + $1.vertexCount * 24 }
        }
        return materials
    }
}
