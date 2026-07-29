import Foundation

public extension Geometry3D {
    /// Applies an edge shape, such as a chamfer or fillet, to the edges of this geometry
    /// matching a query.
    ///
    /// Edges are found in the evaluated geometry and modified according to their convexity:
    /// convex (outside) edges have the shape cut away, while concave (inside corner) edges
    /// have it added as material.
    ///
    /// ```swift
    /// Box(10).shapingEdges(.fillet(radius: 2), matching: .along(.z))
    /// ```
    ///
    /// - Parameters:
    ///   - shape: The cross-section to apply along the edges.
    ///   - query: Criteria selecting which edges to shape. Pass `.all` explicitly to shape every
    ///     edge found under the default sharpness threshold.
    /// - Returns: The geometry with the matching edges shaped.
    ///
    func shapingEdges(_ shape: EdgeShape, matching query: EdgeQuery) -> any Geometry3D {
        MaskResolvingShapeEdges(body: self, query: query, shape: shape)
    }

    /// Applies an edge shape, such as a chamfer or fillet, along the given edges.
    ///
    /// Use this together with `readingEdges(matching:)` when you need programmatic control
    /// over edge selection:
    ///
    /// ```swift
    /// geometry.readingEdges(matching: .all) { geometry, edges in
    ///     geometry.shapingEdges(.chamfer(depth: 1), in: edges.filter { $0.length > 5 })
    /// }
    /// ```
    ///
    /// Convex edges have the shape cut away; concave edges have it added as material.
    ///
    /// - Parameters:
    ///   - shape: The cross-section to apply along the edges.
    ///   - edges: The edges to shape, typically found by `readingEdges`.
    /// - Returns: The geometry with the edges shaped.
    ///
    func shapingEdges(_ shape: EdgeShape, in edges: [FoundEdge]) -> any Geometry3D {
        readEnvironment(\.scaledSegmentation) { segmentation in
            CachedNodeTransformer<D3, D3>(
                source: self,
                name: "Cadova.ShapeEdges.explicit",
                parameters: edges, shape, segmentation
            ) { bodyNode, environment, context in
                try await shapedEdgesNode(
                    bodyNode: bodyNode, edges: edges, shape: shape,
                    segmentation: segmentation, environment: environment, context: context
                )
            }
        }
    }
}

/// Resolves any mask geometries in `query` into nodes before computing the cache key, so their
/// identity can be folded in alongside the body (mirroring how `CachedNodeTransformer` folds in
/// the body's own node). This is required because `EdgeQuery`'s mask constraints are excluded from
/// its own `Hashable`/`Codable` conformance — see `MaskConstraint`. Resolving a geometry into a
/// node is cheap (structural only); the actual mesh evaluation happens later, inside the
/// materialized generator, only on a cache miss.
///
/// The body is built first (rather than delegating to `CachedNodeTransformer`, which would build
/// it a second time) so that any tags/anchors it defines are known before masks — which may
/// reference geometry tagged inside the very body being shaped — are resolved.
private struct MaskResolvingShapeEdges: Geometry {
    typealias D = D3

    let body: any Geometry3D
    let query: EdgeQuery
    let shape: EdgeShape

    func _build(in environment: EnvironmentValues, context: _EvaluationContext) async throws -> D3._BuildResult {
        let segmentation = environment.scaledSegmentation
        let bodyResult = try await context.buildResult(for: body, in: environment)

        let maskEnvironment = bodyResult.elements[ifPresent: ReferenceState.self].map {
            environment.withDefinedReferences($0)
        } ?? environment

        let maskNodes = try await query.maskConstraints.asyncMap {
            try await context.buildResult(for: $0.geometry, in: maskEnvironment).node
        }

        let key = NodeCacheKey(
            base: LabeledCacheKey(operationName: "Cadova.ShapeEdges", parameters: [query, shape, segmentation, maskNodes]),
            node: bodyResult.node
        )

        return try await context.materializedResult(buildResult: bodyResult, key: key) {
            let concreteResult = try await context.result(for: bodyResult.node)
            let maskManifolds = try await maskNodes.asyncMap { try await context.result(for: $0).concrete }
            let edges = EdgeExtractor.edges(in: concreteResult.concrete, matching: query, maskManifolds: maskManifolds)
            let outputNode = try await shapedEdgesNode(
                bodyNode: bodyResult.node, edges: edges, shape: shape,
                segmentation: segmentation, environment: environment, context: context
            )
            return try await context.result(for: outputNode)
        }
    }
}

/// Builds the result node: body minus the union of convex edge tools and corner patches,
/// plus the union of concave ones. At most two boolean operations regardless of edge count.
private func shapedEdgesNode(
    bodyNode: D3.Node,
    edges: [FoundEdge],
    shape: EdgeShape,
    segmentation: Segmentation,
    environment: EnvironmentValues,
    context: _EvaluationContext
) async throws -> D3.Node {
    let plan = EdgeJunctionPlanner.plan(edges: edges, shape: shape)

    let tools = plan.edges.enumerated().map { index, edge in
        EdgeToolSweep.tool(
            for: edge,
            shape: shape,
            segmentation: segmentation,
            startRetraction: plan.retractions[index].start,
            endRetraction: plan.retractions[index].end
        )
    }

    func patchGeometry(for patch: EdgeJunctionPlanner.Patch) -> (any Geometry3D)? {
        let hullPoints = patch.ends.flatMap { end -> [Vector3D] in
            guard let tool = tools[end.edgeIndex] else { return [] }
            let ring = end.atStart ? tool.startSectionPoints : tool.endSectionPoints

            // Also hull a copy of the ring nudged into the tool, so the patch overlaps it
            // volumetrically; exact face-on-face contact with the tool's end cap can leave
            // degenerate zero-volume shells behind in the boolean operation.
            let edge = plan.edges[end.edgeIndex]
            guard let segment = end.atStart ? edge.segments.first : edge.segments.last else { return ring }
            let intoChain = end.atStart ? segment.direction.unitVector : -segment.direction.unitVector
            return ring + ring.map { $0 + intoChain * EdgeToolSweep.faceOvershoot }
        } + [patch.apexPoint]
        guard hullPoints.count >= 4 else { return nil }

        let hull = hullPoints.convexHull()
        if let sphere = patch.sphere {
            return hull.subtracting {
                Sphere(radius: sphere.radius).translated(sphere.center)
            }
        }
        return hull
    }

    func nodes(convex: Bool) async throws -> [D3.Node] {
        var geometries: [any Geometry3D] = plan.edges.indices.compactMap { index in
            plan.edges[index].isConvex == convex ? tools[index]?.geometry : nil
        }
        geometries += plan.patches.compactMap { patch in
            patch.isConvex == convex ? patchGeometry(for: patch) : nil
        }

        var result: [D3.Node] = []
        for geometry in geometries {
            result.append(try await context.buildResult(for: geometry, in: environment).node)
        }
        return result
    }

    let cutters = try await nodes(convex: true)
    let fillers = try await nodes(convex: false)

    var node = bodyNode
    if !cutters.isEmpty {
        node = .boolean([node, .boolean(cutters, type: .union)], type: .difference)
    }
    if !fillers.isEmpty {
        node = .boolean([node] + fillers, type: .union)
    }
    return node
}
