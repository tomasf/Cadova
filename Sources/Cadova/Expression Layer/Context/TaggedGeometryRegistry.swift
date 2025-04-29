import Foundation
import Manifold3D

actor TaggedGeometryRegistry {
    private var table: [OpaqueKey: Set<Manifold.OriginalID>] = [:]

    func tag(_ mesh: Manifold, with key: OpaqueKey) -> Manifold {
        let original = mesh.asOriginal()
        guard let originalID = original.originalID else {
            preconditionFailure("Original geometry should always have an ID")
        }
        table[key, default: []].insert(originalID)
        return original
    }

    subscript<Key: CacheKey>(key: Key) -> Set<Manifold.OriginalID> {
        get { table[OpaqueKey(key)] ?? [] }
        set { table[OpaqueKey(key)] = newValue }
    }

    var mapping: [OpaqueKey: Set<Manifold.OriginalID>] {
        table
    }
}
