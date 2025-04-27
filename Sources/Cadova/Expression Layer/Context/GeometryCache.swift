import Foundation
import Manifold3D

actor GeometryCache<D: Dimensionality> {
    private var entries: [D.Expression: Task<D.Primitive, Never>] = [:]

    func cachedGeometry(for expression: D.Expression) async -> D.Primitive? {
        await entries[expression]?.value
    }

    func setCachedGeometry(_ primitive: D.Primitive, for expression: D.Expression) {
        entries[expression] = Task { primitive }
    }

    func geometry(for expression: D.Expression, in context: EvaluationContext) async -> D.Primitive {
        guard !expression.isEmpty else { return .empty }

        if let cached = await cachedGeometry(for: expression) {
            return cached
        }
        let task = Task { await expression.evaluate(in: context) }
        entries[expression] = task
        return await task.value
    }

    var count: Int {
        entries.count
    }

    func debugPrint() {
        for key in entries.keys {
            print(key.debugDescription)
        }
    }
}
