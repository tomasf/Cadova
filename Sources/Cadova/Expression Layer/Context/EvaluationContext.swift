import Foundation
import Manifold3D

public struct EvaluationContext: Sendable {
    internal let cache: GeometryCache
    internal let materials: MaterialRegistry

    internal init(cache: GeometryCache, materials: MaterialRegistry) {
        self.cache = cache
        self.materials = materials
    }
}

extension EvaluationContext {
    init() {
        self.init(cache: .init(), materials: .init())
    }
}

public typealias CacheKey = Hashable & Sendable & Codable

extension EvaluationContext {
    func cachedRawGeometry<E: GeometryExpression, Key: CacheKey>(for source: E?, key: Key) async -> E? {
        let wrappedKey = ExpressionKey(key)
        let expression = E.raw(.empty, source: source, cacheKey: wrappedKey)

        if let expression = expression as? GeometryExpression2D {
            guard let primitive = await cache.cachedGeometry(for: expression) else { return nil }
            return .raw(primitive as! E.D.Primitive, source: source, cacheKey: wrappedKey)

        } else if let expression = expression as? GeometryExpression3D {
            guard let primitive = await cache.cachedGeometry(for: expression) else { return nil }
            return .raw(primitive as! E.D.Primitive, source: source, cacheKey: wrappedKey)

        } else {
            preconditionFailure("Unknown geometry type")
        }
    }

    func geometry<Expression: GeometryExpression>(for expression: Expression) async -> Expression.D.Primitive {
        if let expression = expression as? GeometryExpression2D {
            return await cache.geometry(for: expression, in: self) as! Expression.D.Primitive
        } else if let expression = expression as? GeometryExpression3D {
            return await cache.geometry(for: expression, in: self) as! Expression.D.Primitive
        } else {
            preconditionFailure("Unknown geometry type")
        }
    }

    func geometries<E: GeometryExpression>(for expressions: [E]) async -> [E.D.Primitive] {
        await expressions.asyncMap { await self.geometry(for: $0) }
    }
}

extension EvaluationContext {
    func assign(_ material: Material, to originalID: Manifold.OriginalID) async {
        await materials.register(material, for: originalID)
    }
}
