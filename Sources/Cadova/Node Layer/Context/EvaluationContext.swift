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
    func result<Expression: GeometryNode>(for expression: Expression) async -> Expression.Result {
        if let expression = expression as? GeometryNode2D {
            return await cache2D.result(for: expression, in: self) as! Expression.Result
        } else if let expression = expression as? GeometryNode3D {
            return await cache3D.result(for: expression, in: self) as! Expression.Result
        } else {
            preconditionFailure("Unknown geometry type")
        }
    }

    func results<E: GeometryNode>(for expressions: [E]) async -> [E.Result] {
        await expressions.asyncMap { await self.result(for: $0) }
    }

    // MARK: - Materialized results

    func cachedMaterializedResult<D: Dimensionality, Key: CacheKey>(key: Key) async -> EvaluationResult<D>? {
        let wrappedKey = OpaqueKey(key)
        let expression = D.Node.materialized(cacheKey: wrappedKey)

        if let expression = expression as? GeometryNode2D {
            return await cache2D.cachedResult(for: expression) as! EvaluationResult<D>?

        } else if let expression = expression as? GeometryNode3D {
            return await cache3D.cachedResult(for: expression) as! EvaluationResult<D>?

        } else {
            preconditionFailure("Unknown geometry type")
        }
    }

    func hasCachedResult<D: Dimensionality>(for key: any CacheKey, with dimensionality: D.Type) async -> Bool {
        (await cachedMaterializedResult(key: key) as D.Node.Result?) != nil
    }

    func storeMaterializedResult<E: GeometryNode, Key: CacheKey>(_ result: E.Result, key: Key) async -> E {
        let wrappedKey = OpaqueKey(key)
        let expression = E.materialized(cacheKey: wrappedKey)

        if let expression = expression as? GeometryNode2D {
            await cache2D.setCachedResult(result as! D2.Node.Result, for: expression)

        } else if let expression = expression as? GeometryNode3D {
            await cache3D.setCachedResult(result as! D3.Node.Result, for: expression)

        } else {
            preconditionFailure("Unknown geometry type")
        }

        return expression
    }

    // MARK: - Result elements

    func resultElements(for cacheKey: any CacheKey) async -> ResultElements? {
        await resultElementCache.entries[OpaqueKey(cacheKey)]
    }

    func setResultElements(_ elements: ResultElements?, for cacheKey: any CacheKey) async {
        await resultElementCache.setResultElements(elements, for: .init(cacheKey))
    }
}
