import Foundation
import Manifold3D

public struct EvaluationContext: Sendable {
    internal let cache2D = GeometryCache<D2>()
    internal let cache3D = GeometryCache<D3>()
    internal let resultElementCache = ResultElementCache()
    internal init() {}
}

public typealias CacheKey = Hashable & Sendable & Codable

internal extension EvaluationContext {
    func result<D: Dimensionality>(for node: D.Node) async -> EvaluationResult<D> {
        if let node = node as? D2.Node {
            return await cache2D.result(for: node, in: self) as! EvaluationResult<D>
        } else if let node = node as? D3.Node {
            return await cache3D.result(for: node, in: self) as! EvaluationResult<D>
        } else {
            preconditionFailure("Unknown geometry type")
        }
    }

    func results<D: Dimensionality>(for nodes: [D.Node]) async -> [EvaluationResult<D>] {
        await nodes.asyncMap { await self.result(for: $0) }
    }

    // MARK: - Materialized results

    func cachedMaterializedResult<D: Dimensionality, Key: CacheKey>(key: Key) async -> EvaluationResult<D>? {
        let wrappedKey = OpaqueKey(key)
        let node = D.Node.materialized(cacheKey: wrappedKey)

        if let node = node as? D2.Node {
            return await cache2D.cachedResult(for: node) as! EvaluationResult<D>?

        } else if let node = node as? D3.Node {
            return await cache3D.cachedResult(for: node) as! EvaluationResult<D>?

        } else {
            preconditionFailure("Unknown geometry type")
        }
    }

    func hasCachedResult<D: Dimensionality>(for key: any CacheKey, with dimensionality: D.Type) async -> Bool {
        (await cachedMaterializedResult(key: key) as D.Node.Result?) != nil
    }

    func storeMaterializedResult<D: Dimensionality, Key: CacheKey>(_ result: EvaluationResult<D>, key: Key) async -> D.Node {
        let wrappedKey = OpaqueKey(key)
        let node = D.Node.materialized(cacheKey: wrappedKey)

        if let node = node as? D2.Node {
            await cache2D.setCachedResult(result as! D2.Node.Result, for: node)

        } else if let node = node as? D3.Node {
            await cache3D.setCachedResult(result as! D3.Node.Result, for: node)

        } else {
            preconditionFailure("Unknown geometry type")
        }

        return node
    }

    // MARK: - Result elements

    func resultElements(for cacheKey: any CacheKey) async -> ResultElements? {
        await resultElementCache.entries[OpaqueKey(cacheKey)]
    }

    func setResultElements(_ elements: ResultElements?, for cacheKey: any CacheKey) async {
        await resultElementCache.setResultElements(elements, for: .init(cacheKey))
    }
}
