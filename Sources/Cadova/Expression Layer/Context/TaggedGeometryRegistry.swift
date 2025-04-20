import Foundation
import Manifold3D

actor TaggedGeometryRegistry {
    private var table: [ExpressionKey: Manifold.OriginalID] = [:]

    func tag(_ mesh: Manifold, with key: ExpressionKey) -> Manifold {
        let original = mesh.asOriginal()
        guard let originalID = original.originalID else {
            preconditionFailure("Original geometry should always have an ID")
        }
        table[key] = originalID
        return original
    }

    subscript<Key: CacheKey>(key: Key) -> Manifold.OriginalID? {
        get { table[ExpressionKey(key)] }
        set { table[ExpressionKey(key)] = newValue }
    }

    var mapping: [ExpressionKey: Manifold.OriginalID] {
        table
    }
}
