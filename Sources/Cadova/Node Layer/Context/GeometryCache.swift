import Foundation
import Manifold3D

// GeometryCache maintains a mapping between geometry nodes and concrete geometry to avoid repeated evaluation

internal actor GeometryCache<D: Dimensionality> {
    private var entries: [D.Node: Task<D.Node.Result, any Error>] = [:]
    private var bodyEntries: [AnyCacheKey: Task<BuildResult<D>, any Error>] = [:]

    @_specialize(exported: false, where D == D2)
    @_specialize(exported: false, where D == D3)
    func result(for node: D.Node, in context: EvaluationContext) async throws -> D.Node.Result {
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

    // Coalesces concurrent/repeated calls sharing the same key onto a single `body` build, so
    // `CachedGeometry` bodies run at most once per key while still surfacing that build's result
    // elements (which, unlike node evaluation, can't be deferred to mesh-realization time).
    func bodyResult(for key: AnyCacheKey, generator: @escaping @Sendable () async throws -> BuildResult<D>) async throws -> BuildResult<D> {
        if let existing = bodyEntries[key] {
            return try await existing.value
        }
        let task = Task(operation: generator)
        bodyEntries[key] = task
        return try await task.value
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
