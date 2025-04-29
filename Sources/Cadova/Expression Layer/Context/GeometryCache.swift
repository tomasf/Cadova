import Foundation
import Manifold3D

actor GeometryCache<D: Dimensionality> {
    private var entries: [D.Expression: Task<D.Expression.Result, Never>] = [:]

    func cachedResult(for expression: D.Expression) async -> D.Expression.Result? {
        await entries[expression]?.value
    }

    func setCachedResult(_ primitive: D.Expression.Result, for expression: D.Expression) {
        entries[expression] = Task { primitive }
    }

    func result(for expression: D.Expression, in context: EvaluationContext) async -> D.Expression.Result {
        guard !expression.isEmpty else { return .empty }

        if let cached = await cachedResult(for: expression) {
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
