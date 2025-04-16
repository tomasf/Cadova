import Foundation
import Manifold3D

actor GeometryCache {
    private var cache2D: [GeometryExpression2D: Task<CrossSection, Never>] = [:]
    private var cache3D: [GeometryExpression3D: Task<Manifold, Never>] = [:]

    func geometry(for expression: GeometryExpression2D, in context: EvaluationContext) async -> CrossSection {
        guard !expression.isEmpty else { return .empty }

        if expression.isCacheable {
            if let cached = cache2D[expression] {
                return await cached.value
            }
            let task = Task { await expression.evaluate(in: context) }
            cache2D[expression] = task
            return await task.value
        } else {
            return await expression.evaluate(in: context)
        }
    }

    func geometry(for expression: GeometryExpression3D, in context: EvaluationContext) async -> Manifold {
        guard !expression.isEmpty else { return .empty }

        if expression.isCacheable {
            if let cached = cache3D[expression] {
                return await cached.value
            }
            let task = Task { await expression.evaluate(in: context) }
            cache3D[expression] = task
            return await task.value
        } else {
            return await expression.evaluate(in: context)
        }
    }
}
