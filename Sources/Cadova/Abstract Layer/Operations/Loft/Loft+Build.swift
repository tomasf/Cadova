import Foundation

extension Loft {
    public func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<D> {
        let layerNodes = try await layers.asyncMap {
            LayerNode(
                z: $0.z,
                transition: $0.transition,
                node: try await context.buildResult(for: $0.geometry(), in: environment).node
            )
        }

        let cachedConcrete = CachedConcrete<D3, _>(
            name: "loft",
            parameters: layerNodes, shapingFunction
        ) {
            let layerTrees = try await layerNodes.asyncMap {
                TreeLayer(
                    z: $0.z,
                    transition: $0.transition,
                    tree: try await context.result(for: $0.node).concrete.polygonTree()
                )
            }

            // Always use resampled loft. Apply per-layer override or default Loft.shapingFunction.
            let resamplingLayers = layerTrees.map { $0.resamplingLayer(with: shapingFunction) }
            let geometry = await Loft.resampledLoft(resamplingLayers: resamplingLayers, in: environment, context: context)
            return try await context.result(for: geometry, in: environment).concrete
        }

        return try await context.buildResult(for: cachedConcrete, in: environment)
    }

    internal struct LayerNode: CacheKey {
        let z: Double
        let transition: LayerTransition?
        let node: D2.Node
    }

    // Internal helper to bridge from built 2D polygon trees to resampling layers
    internal struct TreeLayer {
        let z: Double
        let transition: LayerTransition?
        let tree: PolygonTree

        func resamplingLayer(with defaultFunction: ShapingFunction) -> Loft.ResamplingLayer {
            let resolvedTransition = transition ?? .interpolated(defaultFunction)
            return Loft.ResamplingLayer(z: z, transition: resolvedTransition, tree: tree)
        }
    }
}
