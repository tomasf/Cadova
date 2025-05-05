import Foundation
import Manifold3D

// GeometryCache maintains a mapping between geometry nodes and concrete geometry to avoid repeated evaluation

actor GeometryCache<D: Dimensionality> {
    private var entries: [D.Node: Task<D.Node.Result, Never>] = [:]

    func cachedResult(for node: D.Node) async -> D.Node.Result? {
        await entries[node]?.value
    }

    func setCachedResult(_ result: D.Node.Result, for node: D.Node) {
        entries[node] = Task { result.modified { $0.baked() } }
    }

    func result(for node: D.Node, in context: EvaluationContext) async -> D.Node.Result {
        guard !node.isEmpty else { return .empty }

        if let cached = await cachedResult(for: node) {
            return cached
        }
        let task = Task { await node.evaluate(in: context).modified { $0.baked() } }
        entries[node] = task
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
