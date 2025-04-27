import Foundation
import Manifold3D

public struct EvaluationContext: Sendable {
    internal let cache2D = GeometryCache<D2>()
    internal let cache3D = GeometryCache<D3>()
    internal let taggedGeometry = TaggedGeometryRegistry()
    internal let resultElementCache = ResultElementCache()
    internal init() {}
}

public typealias CacheKey = Hashable & Sendable & Codable

internal extension EvaluationContext {
    func cachedRawGeometry<P: PrimitiveGeometry, Key: CacheKey>(key: Key) async -> P? {
        let wrappedKey = OpaqueKey(key)
        let expression = P.D.Expression.raw(cacheKey: wrappedKey)

        if let expression = expression as? GeometryExpression2D {
            return await cache2D.cachedGeometry(for: expression) as! P?

        } else if let expression = expression as? GeometryExpression3D {
            return await cache3D.cachedGeometry(for: expression) as! P?

        } else {
            preconditionFailure("Unknown geometry type")
        }
    }

    func hasCachedGeometry<D: Dimensionality>(for key: any CacheKey, with dimensionality: D.Type) async -> Bool {
        (await cachedRawGeometry(key: key) as D.Primitive?) != nil
    }

    func storeRawGeometry<E: GeometryExpression, Key: CacheKey>(_ primitive: E.D.Primitive, key: Key) async -> E {
        let wrappedKey = OpaqueKey(key)
        let expression = E.raw(cacheKey: wrappedKey)

        if let expression = expression as? GeometryExpression2D {
            await cache2D.setCachedGeometry(primitive as! D2.Primitive, for: expression)

        } else if let expression = expression as? GeometryExpression3D {
            await cache3D.setCachedGeometry(primitive as! D3.Primitive, for: expression)

        } else {
            preconditionFailure("Unknown geometry type")
        }

        return expression
    }

    func geometry<Expression: GeometryExpression>(for expression: Expression) async -> Expression.D.Primitive {
        if let expression = expression as? GeometryExpression2D {
            return await cache2D.geometry(for: expression, in: self) as! Expression.D.Primitive
        } else if let expression = expression as? GeometryExpression3D {
            return await cache3D.geometry(for: expression, in: self) as! Expression.D.Primitive
        } else {
            preconditionFailure("Unknown geometry type")
        }
    }

    func geometries<E: GeometryExpression>(for expressions: [E]) async -> [E.D.Primitive] {
        await expressions.asyncMap { await self.geometry(for: $0) }
    }

    func resultElements(for cacheKey: any CacheKey) async -> ResultElements? {
        await resultElementCache.entries[OpaqueKey(cacheKey)]
    }

    func setResultElements(_ elements: ResultElements?, for cacheKey: any CacheKey) async {
        await resultElementCache.setResultElements(elements, for: .init(cacheKey))
    }
}
