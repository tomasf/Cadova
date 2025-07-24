import Foundation

extension Loft {
    public func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<D> {
        let layerNodes = try await layers.asyncMap {
            LayerCacheKey(
                z: $0.z,
                function: $0.shapingFunction,
                node: try await context.buildResult(for: $0.geometry, in: environment).node
            )
        }

        let cachedConcrete = CachedConcrete<D3, _>(name: "loft", parameters: layerNodes, interpolation) {
            let layerTrees = try await layerNodes.asyncMap {
                LayerInterpolation.TreeLayer(
                    z: $0.z,
                    function: $0.function,
                    tree: try await context.result(for: $0.node).concrete.polygonTree()
                )
            }

            return try await context.result(
                for: interpolation.resolved(with: layerTrees).applied(to: layerTrees, in: environment),
                in: environment
            ).concrete
        }

        return try await context.buildResult(for: cachedConcrete, in: environment)
    }

    internal struct LayerCacheKey: CacheKey {
        let z: Double
        let function: ShapingFunction?
        let node: D2.Node
    }
}

internal extension Loft.LayerInterpolation {
    struct TreeLayer {
        let z: Double
        let function: ShapingFunction?
        let tree: PolygonTree

        func resamplingLayer(with defaultFunction: ShapingFunction) -> ResamplingLayer {
            ResamplingLayer(z: z, function: function ?? defaultFunction, tree: tree)
        }
    }

    func resolved(with layers: [TreeLayer]) async -> Self {
        guard self == .automatic else { return self }

        let useConvex = layers.allSatisfy {
            $0.function == nil && $0.tree.children.count == 1 && $0.tree.children[0].polygon.isConvex
        }

        return useConvex ? .convexHull : .resampled
    }

    func applied(to layers: [TreeLayer], in environment: EnvironmentValues) async -> any Geometry3D {
        switch self {
        case .convexHull:
            let flattenedLayers = layers.map { ($0.z, $0.tree.flattened()) }

            return flattenedLayers.paired().map(unpacked).mapUnion { z1, list1, z2, list2 in
                let bottomPoints = list1.polygons.flatMap { $0.vertices(at: z1) }
                let topPoints = list2.polygons.flatMap { $0.vertices(at: z2) }
                (bottomPoints + topPoints).convexHull()
            }

        case .resampled (let function):
            let resamplingLayers = layers.map { $0.resamplingLayer(with: function) }
            return await resampledLoft(treeLayers: resamplingLayers, in: environment)

        case .automatic: preconditionFailure()
        }
    }
}
