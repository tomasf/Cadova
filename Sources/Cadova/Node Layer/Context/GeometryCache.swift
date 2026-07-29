import Foundation
import Manifold3D

// GeometryCache maintains a mapping between geometry nodes and concrete geometry to avoid repeated evaluation

internal actor GeometryCache<D: Dimensionality> {
    private var entries: [D.Node: Task<D.Node.Result, any Error>] = [:]

    @_specialize(exported: false, where D == D2)
    @_specialize(exported: false, where D == D3)
    func result(for node: D.Node, in context: _EvaluationContext) async throws -> D.Node.Result {
        guard !node.isEmpty else { return .empty }

        if let cached = try await entries[node]?.value {
            return cached
        }
        let task = Task { try await node.evaluate(in: context) }
        entries[node] = task
        return try await task.value
    }

    func declareGenerator(for node: D.Node, generator: @escaping @Sendable () async throws -> D.Node.Result) async throws {
        if entries[node] == nil {
            entries[node] = Task(operation: generator)
        }
    }
}

internal extension GeometryCache {
    var count: Int {
        entries.count
    }

    func debugPrint() {
        for key in entries.keys {
            print(key.debugDescription)
        }
    }
}
