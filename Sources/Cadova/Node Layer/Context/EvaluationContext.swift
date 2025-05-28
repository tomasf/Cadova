import Foundation
import Manifold3D

public struct EvaluationContext: Sendable {
    internal let cache2D = GeometryCache<D2>()
    internal let cache3D = GeometryCache<D3>()

    internal init() {}
}

public typealias CacheKey = Hashable & Sendable & Codable

internal extension EvaluationContext {
    private func cache<D: Dimensionality>() -> GeometryCache<D> {
        switch D.self {
        case is D2.Type: cache2D as! GeometryCache<D>
        case is D3.Type: cache3D as! GeometryCache<D>
        default: fatalError()
        }
    }

    func result<D: Dimensionality>(for node: D.Node) async -> EvaluationResult<D> {
        await cache().result(for: node, in: self)
    }

    func results<D: Dimensionality>(for nodes: [D.Node]) async -> [EvaluationResult<D>] {
        await nodes.asyncMap { await self.result(for: $0) }
    }

    // MARK: - Materialized results

    func cachedMaterializedResult<D: Dimensionality, Key: CacheKey>(
        key: Key
    ) async -> EvaluationResult<D>? {
        await cache().cachedResult(for: .materialized(cacheKey: OpaqueKey(key)))
    }

    func hasCachedResult<D: Dimensionality, Key: CacheKey>(
        for key: Key,
        with dimensionality: D.Type
    ) async -> Bool {
        (await cachedMaterializedResult(key: key) as EvaluationResult<D>?) != nil
    }

    func storeMaterializedResult<D: Dimensionality, Key: CacheKey>(
        _ result: EvaluationResult<D>,
        key: Key
    ) async -> D.Node {
        let node = D.Node.materialized(cacheKey: OpaqueKey(key))
        await cache().setCachedResult(result, for: node)
        return node
    }
}
