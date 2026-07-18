import Foundation

extension Loft {
    public func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<D> {
        let sectionNodes = try await sections.asyncMap {
            SectionNode(
                distance: $0.distance,
                transition: $0.transition,
                node: try await context.buildResult(for: $0.geometry(), in: environment).node
            )
        }

        let cachedConcrete = CachedConcrete<D3, _>(
            name: "loft",
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

            let frames = path.curve.frames(
                environment: environment,
                target: target,
                targetReference: reference,
                perpendicularBounds: perpendicularBounds,
                miteringCorners: true
            )

            let geometry = await Loft.resampledLoft(
                resamplingSections: resamplingSections, frames: frames, curve: path.curve,
                reference: reference, target: target, in: environment, context: context
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
