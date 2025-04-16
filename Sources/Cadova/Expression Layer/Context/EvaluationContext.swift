import Foundation
import Manifold3D

struct EvaluationContext {
    let cache: GeometryCache
    let materials: MaterialRegistry

    init(cache: GeometryCache, materials: MaterialRegistry) {
        self.cache = cache
        self.materials = materials
    }
}

extension EvaluationContext {
    init() {
        self.init(cache: .init(), materials: .init())
    }
}

extension EvaluationContext {
    func geometry(for expression: GeometryExpression2D) async -> CrossSection {
        await cache.geometry(for: expression, in: self)
    }

    func geometry(for expression: GeometryExpression3D) async -> Manifold {
        await cache.geometry(for: expression, in: self)
    }

    func geometries(for expressions: [GeometryExpression2D]) async -> [CrossSection] {
        await expressions.asyncMap { await self.geometry(for: $0) }
    }

    func geometries(for expressions: [GeometryExpression3D]) async -> [Manifold] {
        await expressions.asyncMap { await self.geometry(for: $0) }
    }
}

extension EvaluationContext {
    func assign(_ material: Material, to originalID: Manifold.OriginalID) async {
        await materials.register(material, for: originalID)
    }
}
