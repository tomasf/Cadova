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
    func cachedMaterializedGeometry<P: PrimitiveGeometry, Key: CacheKey>(key: Key) async -> P? {
        let wrappedKey = OpaqueKey(key)
        let expression = P.D.Expression.materialized(cacheKey: wrappedKey)

        if let expression = expression as? GeometryExpression2D {
            return await cache2D.cachedGeometry(for: expression) as! P?

        } else if let expression = expression as? GeometryExpression3D {
            return await cache3D.cachedGeometry(for: expression) as! P?

        } else {
            preconditionFailure("Unknown geometry type")
        }
    }

    func hasCachedGeometry<D: Dimensionality>(for key: any CacheKey, with dimensionality: D.Type) async -> Bool {
        (await cachedMaterializedGeometry(key: key) as D.Primitive?) != nil
    }

    func storeMaterializedGeometry<E: GeometryExpression, Key: CacheKey>(_ primitive: E.Result, key: Key) async -> E {
        let wrappedKey = OpaqueKey(key)
        let expression = E.materialized(cacheKey: wrappedKey)

        if let expression = expression as? GeometryExpression2D {
            await cache2D.setCachedGeometry(primitive as! D2.Expression.Result, for: expression)

        } else if let expression = expression as? GeometryExpression3D {
            await cache3D.setCachedGeometry(primitive as! D3.Expression.Result, for: expression)

        } else {
            preconditionFailure("Unknown geometry type")
        }

        return expression
    }

    func geometry<Expression: GeometryExpression>(for expression: Expression) async -> Expression.Result {
        if let expression = expression as? GeometryExpression2D {
            return await cache2D.geometry(for: expression, in: self) as! Expression.Result
        } else if let expression = expression as? GeometryExpression3D {
            return await cache3D.geometry(for: expression, in: self) as! Expression.Result
        } else {
            preconditionFailure("Unknown geometry type")
        }
    }

    func geometries<E: GeometryExpression>(for expressions: [E]) async -> [E.Result] {
        await expressions.asyncMap { await self.geometry(for: $0) }
    }

    func resultElements(for cacheKey: any CacheKey) async -> ResultElements? {
        await resultElementCache.entries[OpaqueKey(cacheKey)]
    }

    func setResultElements(_ elements: ResultElements?, for cacheKey: any CacheKey) async {
        await resultElementCache.setResultElements(elements, for: .init(cacheKey))
    }
}
