import Foundation
import Manifold3D

public struct EvaluationContext: Sendable {
    internal let cache2D: GeometryCache<D2> = .init()
    internal let cache3D: GeometryCache<D3> = .init()
    internal let taggedGeometry: TaggedGeometryRegistry = .init()

    internal init() {}
}

public typealias CacheKey = Hashable & Sendable & Codable

internal extension EvaluationContext {
    func cachedRawGeometry<E: GeometryExpression, Key: CacheKey>(for source: E?, key: Key) async -> E? {
        let wrappedKey = OpaqueKey(key)
        let expression = E.raw(.empty, source: source, cacheKey: wrappedKey)

        if let expression = expression as? GeometryExpression2D {
            guard let primitive = await cache2D.cachedGeometry(for: expression) else { return nil }
            return .raw(primitive as! E.D.Primitive, source: source, cacheKey: wrappedKey)

        } else if let expression = expression as? GeometryExpression3D {
            guard let primitive = await cache3D.cachedGeometry(for: expression) else { return nil }
            return .raw(primitive as! E.D.Primitive, source: source, cacheKey: wrappedKey)

        } else {
            preconditionFailure("Unknown geometry type")
        }
    }

    func storeRawGeometry<E: GeometryExpression, Key: CacheKey>(_ geometry: E.D.Primitive, for source: E?, key: Key) async -> E {
        let wrappedKey = OpaqueKey(key)
        let expression = E.raw(geometry, source: source, cacheKey: wrappedKey)

        if let expression = expression as? GeometryExpression2D {
            _ = await cache2D.geometry(for: expression, in: self)

        } else if let expression = expression as? GeometryExpression3D {
            _ = await cache3D.geometry(for: expression, in: self)

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
}
