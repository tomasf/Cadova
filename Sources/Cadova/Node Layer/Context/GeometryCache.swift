import Foundation
import Manifold3D

// GeometryCache maintains a mapping between geometry nodes and concrete geometry to avoid repeated evaluation

internal actor GeometryCache<D: Dimensionality> {
    private var entries: [D.Node: Task<D.Node.Result, any Error>] = [:]
    private var multipartCounts: [OpaqueKey: Task<Int, any Error>] = [:]

    func result(for node: D.Node, in context: EvaluationContext) async throws -> D.Node.Result {
        guard !node.isEmpty else { return .empty }

        if let cached = try await entries[node]?.value {
            return cached
        }
        let task = Task { try await node.evaluate(in: context).modified { $0.baked() } }
        entries[node] = task
        return try await task.value
    }

    func declareGenerator(for node: D.Node, generator: @escaping @Sendable () async throws -> D.Node.Result) async throws {
        if entries[node] == nil {
            entries[node] = Task(operation: generator)
        }
    }

    func multipartCount<Key: CacheKey>(
        for key: Key,
        generator: @escaping @Sendable () async throws -> [D.Node.Result]
    ) async throws -> Int {
        let opaqueKey = OpaqueKey(key)
        if let task = multipartCounts[opaqueKey] {
            return try await task.value
        } else {
            let task = Task {
                let results = try await generator()
                for (index, item) in results.enumerated() {
                    let key = IndexedCacheKey(base: key, index: index)
                    self.entries[.materialized(cacheKey: OpaqueKey(key))] = Task { item }
                }
                return results.count
            }
            multipartCounts[opaqueKey] = task
            return try await task.value
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
