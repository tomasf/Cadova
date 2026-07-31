import Foundation

internal struct ReadEdges: Geometry {
    typealias D = D3

    let body: any Geometry3D
    let query: EdgeQuery
    let action: @Sendable (BuildResult<D3>, [FoundEdge]) -> any Geometry3D

    func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<D3> {
        let bodyResult = try await context.buildResult(for: body, in: environment)
        let concreteResult = try await context.result(for: bodyResult.node)

        // Let mask geometry see tags/anchors defined inside the body, so a mask can reference
        // geometry tagged within the body being searched, not just siblings above this call.
        let maskEnvironment = bodyResult.elements[ifPresent: ReferenceState.self].map {
            environment.withDefinedReferences($0)
        } ?? environment

        let maskManifolds = try await query.maskConstraints.asyncMap {
            try await context.result(for: $0.geometry, in: maskEnvironment).concrete
        }
        let edges = EdgeExtractor.edges(in: concreteResult.concrete, matching: query, maskManifolds: maskManifolds)
        return try await context.buildResult(for: action(bodyResult, edges), in: environment)
    }
}

public extension Geometry3D {
    /// Evaluates this geometry, finds edges matching `query`, then passes both to a builder closure.
    ///
    /// Use this to drive per-edge operations like visualization, measurement, or custom modifications:
    ///
    /// ```swift
    /// geometry.readingEdges(matching: .along(.z)) { geometry, edges in
    ///     geometry.visualizingEdges(edges.filter { $0.length > 5 })
    /// }
    /// ```
    ///
    /// The `geometry` parameter of the closure is the already-evaluated body; operations
    /// on it hit the evaluation cache, so the geometry is not evaluated twice.
    ///
    /// - Parameters:
    ///   - query: The criteria used to select edges. Defaults to `.all`.
    ///   - action: A closure that receives the evaluated geometry and the found edges.
    /// - Returns: The geometry produced by `action`.
    ///
    func readingEdges(
        matching query: EdgeQuery = .all,
        @GeometryBuilder3D _ action: @Sendable @escaping (any Geometry3D, [FoundEdge]) -> any Geometry3D
    ) -> any Geometry3D {
        ReadEdges(body: self, query: query, action: action)
    }
}
