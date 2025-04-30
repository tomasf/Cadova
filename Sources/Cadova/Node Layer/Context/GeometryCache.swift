import Foundation
import Manifold3D

// GeometryCache maintains a mapping between geometry nodes and concrete geometry to avoid repeated evaluation

actor GeometryCache<D: Dimensionality> {
    private var entries: [D.Node: Task<D.Node.Result, Never>] = [:]

    func cachedResult(for expression: D.Node) async -> D.Node.Result? {
        await entries[expression]?.value
    }

    func setCachedResult(_ concrete: D.Node.Result, for expression: D.Node) {
        entries[expression] = Task { concrete }
    }

    func result(for expression: D.Node, in context: EvaluationContext) async -> D.Node.Result {
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
