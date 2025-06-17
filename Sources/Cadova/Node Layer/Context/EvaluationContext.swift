import Foundation
import Manifold3D

public struct EvaluationContext: Sendable {
    internal let cache2D = GeometryCache<D2>()
    internal let cache3D = GeometryCache<D3>()

    internal init() {}
}

internal extension EvaluationContext {
    private func cache<D: Dimensionality>() -> GeometryCache<D> {
        switch D.self {
        case is D2.Type: cache2D as! GeometryCache<D>
        case is D3.Type: cache3D as! GeometryCache<D>
        default: fatalError()
        }
    }

    func result<D: Dimensionality>(for node: D.Node) async throws -> EvaluationResult<D> {
        try await cache().result(for: node, in: self)
    }

    func results<D: Dimensionality>(for nodes: [D.Node]) async throws -> [EvaluationResult<D>] {
        try await nodes.asyncMap { try await self.result(for: $0) }
    }
}

internal extension EvaluationContext {
    func buildResult<D: Dimensionality>(for geometry: D.Geometry, in environment: EnvironmentValues) async throws -> D.BuildResult {
        try await environment.whileCurrent {
            try await geometry.build(in: environment, context: self)
        }
    }

    func result<D: Dimensionality>(for geometry: D.Geometry, in environment: EnvironmentValues) async throws -> EvaluationResult<D> {
        let buildResult = try await buildResult(for: geometry, in: environment)
        return try await result(for: buildResult.node)
    }
}

internal extension EvaluationContext {
    // MARK: - Materialized results

    func cachedMaterializedResult<D: Dimensionality, Key: CacheKey>(
        key: Key
    ) async throws -> EvaluationResult<D>? {
        try await cache().cachedResult(for: .materialized(cacheKey: OpaqueKey(key)))
    }

    func hasCachedResult<D: Dimensionality, Key: CacheKey>(
        for key: Key,
        with dimensionality: D.Type
    ) async throws -> Bool {
        (try await cachedMaterializedResult(key: key) as EvaluationResult<D>?) != nil
    }

    func storeMaterializedResult<D: Dimensionality, Key: CacheKey>(
        _ result: EvaluationResult<D>,
        key: Key
    ) async -> D.Node {
        let node = D.Node.materialized(cacheKey: OpaqueKey(key))
        await cache().setCachedResult(result, for: node)
        return node
    }
}
