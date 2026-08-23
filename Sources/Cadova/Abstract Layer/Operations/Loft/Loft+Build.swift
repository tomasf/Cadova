import Foundation

extension Loft {
    public func _build(in environment: EnvironmentValues, context: _EvaluationContext) async throws -> _BuildResult<D> {
        // A section is a cross-section of a 3D solid, not a free-standing 2D drawing: a section on a
        // horizontal stretch of path stands upright in space. Build each one in an environment carrying
        // its own frame, so environment values that depend on 3D orientation (notably
        // naturalUpDirection, which drives overhangSafe) reflect where the section actually ends up.
        // These frames are unpruned; pruning needs the sections' combined bounds, so it happens below,
        // once they've been built.
        let unprunedFrames = path.curve.frames(
            environment: environment,
            target: target,
            targetReference: reference,
            perpendicularBounds: nil,
            miteringCorners: true
        )

        let sectionNodes = try await sections.asyncMap { section in
            let frame = path.curve.exactFrame(
                atDistance: section.distance, in: unprunedFrames, reference: reference, target: target
            )
            return SectionNode(
                distance: section.distance,
                transition: section.transition,
                node: try await context.buildResult(
                    for: section.geometry(),
                    in: environment.applyingTransform(frame.rigidTransform)
                ).node
            )
        }

        let cachedConcrete = CachedConcrete<D3, _>(
            name: "Cadova.Loft",
            parameters: sectionNodes, shapingFunction, path, reference, target,
            environment.segmentation, environment.scaledSegmentation, environment.maxTwistRate
        ) {
            let sectionTrees = try await sectionNodes.asyncMap {
                SectionTree(
                    distance: $0.distance,
                    transition: $0.transition,
                    tree: try await context.result(for: $0.node).concrete.polygonTree()
                )
            }

            // Always use resampled loft. Apply per-section override or default Loft.shapingFunction.
            let resamplingSections = sectionTrees.map { $0.resamplingSection(with: shapingFunction) }

            let allVertices = sectionTrees.flatMap { $0.tree.flattened().polygons.flatMap(\.vertices) }
            let perpendicularBounds = allVertices.isEmpty ? BoundingBox2D.zero : BoundingBox2D(allVertices)

            var frames = unprunedFrames
            frames.pruneStraightRuns(bounds: perpendicularBounds, segmentation: environment.segmentation)

            let geometry = await Loft.resampledLoft(
                resamplingSections: resamplingSections, frames: frames, curve: path.curve,
                reference: reference, target: target, in: environment
            )
            return try await context.result(for: geometry, in: environment).concrete
        }

        return try await context.buildResult(for: cachedConcrete, in: environment)
    }

    internal struct SectionNode: CacheKey {
        let distance: Double
        let transition: Transition?
        let node: D2.Node
    }

    // Internal helper to bridge from built 2D polygon trees to resampling sections
    internal struct SectionTree {
        let distance: Double
        let transition: Transition?
        let tree: PolygonTree

        func resamplingSection(with defaultFunction: ShapingFunction) -> Loft.ResamplingSection {
            let resolvedTransition = transition ?? .interpolated(defaultFunction)
            return Loft.ResamplingSection(distance: distance, transition: resolvedTransition, tree: tree)
        }
    }
}
