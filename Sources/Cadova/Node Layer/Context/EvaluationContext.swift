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

    func buildResults<D: Dimensionality>(for geometries: [D.Geometry], in environment: EnvironmentValues) async throws -> [D.BuildResult] {
        try await geometries.asyncMap {
            try await buildResult(for: $0, in: environment)
        }
    }

    func result<D: Dimensionality>(for geometry: D.Geometry, in environment: EnvironmentValues) async throws -> EvaluationResult<D> {
        let buildResult = try await buildResult(for: geometry, in: environment)
        return try await result(for: buildResult.node)
    }
}

internal extension EvaluationContext {
    // MARK: - Materialized results

    func materializedResult<D: Dimensionality, Key: CacheKey>(
        key: Key,
        generator: @escaping @Sendable () async throws -> D.Node.Result
    ) async throws -> D.BuildResult {
        let materializedNode = D.Node.materialized(cacheKey: OpaqueKey(key))
        try await cache().declareGenerator(for: materializedNode, generator: generator)
        return D.BuildResult(materializedNode)
    }

    func materializedResult<D: Dimensionality, Input: Dimensionality, Key: CacheKey>(
        buildResult: Input.BuildResult,
        key: Key,
        generator: @escaping @Sendable () async throws -> D.Node.Result
    ) async throws -> D.BuildResult {
        return try await materializedResult(key: key, generator: generator)
            .replacing(elements: buildResult.elements)
    }

    func multipartMaterializedResults<D: Dimensionality, Key: CacheKey>(
        for key: Key,
        from source: D.BuildResult,
        generator: @escaping @Sendable () async throws -> [D.Node.Result]
    ) async throws -> [BuildResult<D>] {
        let count = try await cache().multipartCount(for: key, generator: generator)
        return (0..<count).map {
            let key = IndexedCacheKey(base: key, index: $0)
            return source.replacing(cacheKey: key)
        }
    }
}
