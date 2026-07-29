import Foundation
import Manifold3D

/// The evaluation/caching context threaded through a ``Geometry`` build.
///
/// This type is public only because it appears in the signature of `Geometry`'s `_build(in:context:)`
/// requirement, which every conforming type must satisfy. It isn't meant to be constructed or used
/// directly — hence the underscore prefix.
public struct _EvaluationContext: Sendable {
    internal let cache2D = GeometryCache<D2>()
    internal let cache3D = GeometryCache<D3>()

    internal init() {}
}

internal extension _EvaluationContext {
    private func cache<D: Dimensionality>() -> GeometryCache<D> {
        switch D.self {
        case is D2.Type: cache2D as! GeometryCache<D>
        case is D3.Type: cache3D as! GeometryCache<D>
        default: fatalError()
        }
    }

    @_specialize(exported: false, where D == D2)
    @_specialize(exported: false, where D == D3)
    func result<D: Dimensionality>(for node: D.Node) async throws -> EvaluationResult<D> {
        try await cache().result(for: node, in: self)
    }

    @_specialize(exported: false, where D == D2)
    @_specialize(exported: false, where D == D3)
    func results<D: Dimensionality>(for nodes: [D.Node]) async throws -> [EvaluationResult<D>] {
        try await nodes.asyncMap { try await self.result(for: $0) }
    }
}

internal extension _EvaluationContext {
    @_specialize(exported: false, where D == D2)
    @_specialize(exported: false, where D == D3)
    func buildResult<D: Dimensionality>(for geometry: D.Geometry, in environment: EnvironmentValues) async throws -> D._BuildResult {
        try await environment.whileCurrent {
            try await geometry._build(in: environment, context: self)
        }
    }

    @_specialize(exported: false, where D == D2)
    @_specialize(exported: false, where D == D3)
    func buildResults<D: Dimensionality>(for geometries: [D.Geometry], in environment: EnvironmentValues) async throws -> [D._BuildResult] {
        try await geometries.asyncMap {
            try await buildResult(for: $0, in: environment)
        }
    }

    @_specialize(exported: false, where D == D2)
    @_specialize(exported: false, where D == D3)
    func result<D: Dimensionality>(for geometry: D.Geometry, in environment: EnvironmentValues) async throws -> EvaluationResult<D> {
        let buildResult = try await buildResult(for: geometry, in: environment)
        return try await result(for: buildResult.node)
    }

    /// Builds geometry as a top-level model, resolving `only()` modifiers.
    ///
    /// Use this method when building geometry for final output (e.g., in Model or for testing).
    /// Unlike `buildResult`, this method:
    /// - Resolves any `only()` modifier, returning the isolated geometry if present
    ///
    func buildModelResult<D: Dimensionality>(for geometry: D.Geometry, in environment: EnvironmentValues) async throws -> D._BuildResult {
        try await buildResult(for: geometry, in: environment).resolvingOnly
    }
}

internal extension _EvaluationContext {
    // MARK: - Materialized results

    func materializedResult<D: Dimensionality, Key: CacheKey>(
        key: Key,
        generator: @escaping @Sendable () async throws -> D.Node.Result
    ) async throws -> D._BuildResult {
        let materializedNode = D.Node.materialized(cacheKey: OpaqueKey(key))
        try await cache().declareGenerator(for: materializedNode, generator: generator)
        return D._BuildResult(materializedNode)
    }

    func materializedResult<D: Dimensionality, Input: Dimensionality, Key: CacheKey>(
        buildResult: Input._BuildResult,
        key: Key,
        generator: @escaping @Sendable () async throws -> D.Node.Result
    ) async throws -> D._BuildResult {
        return try await materializedResult(key: key, generator: generator)
            .replacing(elements: buildResult.elements)
    }
}
