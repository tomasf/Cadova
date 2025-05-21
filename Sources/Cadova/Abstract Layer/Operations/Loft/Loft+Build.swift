import Foundation

extension Loft {
    public func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<D> {
        let layerNodes = try await layers.asyncMap {
            LayerNode(z: $0.z, node: try await $0.geometry.build(in: environment, context: context).node)
        }

        return try await CachedConcrete(name: "loft", parameters: layerNodes, interpolation) {
            let layerTrees = await layerNodes.asyncMap {
                (z: $0.z, tree: await context.result(for: $0.node).concrete.polygonTree())
            }

            let node = try await interpolation
                .resolved(with: layerTrees)
                .applied(to: layerTrees, in: environment)
                .build(in: environment, context: context).node
            return await context.result(for: node).concrete
        }
        .build(in: environment, context: context)
    }

    internal struct LayerNode: CacheKey {
        let z: Double
        let node: D2.Node
    }
}

internal extension Loft.LayerInterpolation {
    typealias TreeLayer = (z: Double, tree: PolygonTree)

    func resolved(with layers: [TreeLayer]) async -> Self {
        guard self == .automatic else { return self }

        let isConvex = layers.allSatisfy {
            $0.tree.children.count == 1 && $0.tree.children[0].polygon.isConvex
        }

        return isConvex ? .convexHull : .resampled
    }

    func applied(to layers: [TreeLayer], in environment: EnvironmentValues) async -> any Geometry3D {
        switch self {
        case .convexHull:
            let flattenedLayers = layers.map { ($0, $1.flattened()) }

            return flattenedLayers.paired().map(unpacked).mapUnion { z1, list1, z2, list2 in
                let bottomPoints = list1.polygons.flatMap { $0.vertices(at: z1) }
                let topPoints = list2.polygons.flatMap { $0.vertices(at: z2) }
                (bottomPoints + topPoints).convexHull()
            }

        case .resampled (let function):
            return await resampledLoft(treeLayers: layers, interpolation: function, in: environment)

        case .automatic: preconditionFailure()
        }
    }
}
