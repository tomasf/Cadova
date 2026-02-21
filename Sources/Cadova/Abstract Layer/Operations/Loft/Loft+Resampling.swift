import Foundation
import Manifold3D

internal extension Loft {
    struct ResamplingLayer {
        let z: Double
        let transition: LayerTransition
        let tree: PolygonTree

        var shapingFunction: ShapingFunction? {
            if case .interpolated(let function) = transition {
                return function
            }
            return nil
        }
    }

    static func resampledLoft(resamplingLayers: [ResamplingLayer], in environment: EnvironmentValues, context: EvaluationContext) async -> any Geometry3D {
        // Find segments that use convex hull transitions
        var convexHullSegments: [(lowerIndex: Int, upperIndex: Int)] = []
        var interpolatedRanges: [Range<Int>] = []
        var currentRangeStart = 0

        for i in 1..<resamplingLayers.count {
            if case .convexHull = resamplingLayers[i].transition {
                // End the current interpolated range if it has at least 2 layers
                if i > currentRangeStart {
                    interpolatedRanges.append(currentRangeStart..<i)
                }
                convexHullSegments.append((i - 1, i))
                currentRangeStart = i
            }
        }

        // Add the final interpolated range
        if resamplingLayers.count > currentRangeStart {
            interpolatedRanges.append(currentRangeStart..<resamplingLayers.count)
        }

        // Build geometry for each segment
        var geometries: [any Geometry3D] = []

        // Process interpolated ranges
        for range in interpolatedRanges {
            if range.count >= 2 {
                let segmentLayers = Array(resamplingLayers[range])
                let geometry = await resampledLoftSegment(resamplingLayers: segmentLayers, in: environment)
                geometries.append(geometry)
            }
        }

        // Process convex hull segments
        for (lowerIndex, upperIndex) in convexHullSegments {
            let lowerLayer = resamplingLayers[lowerIndex]
            let upperLayer = resamplingLayers[upperIndex]
            let geometry = convexHullSegment(lower: lowerLayer, upper: upperLayer)
            geometries.append(geometry)
        }

        return Union(geometries)
    }

    private static func convexHullSegment(lower: ResamplingLayer, upper: ResamplingLayer) -> any Geometry3D {
        // Collect all vertices from both layers at their respective Z heights
        let lowerPoints = lower.tree.flattened().vertices(at: lower.z)
        let upperPoints = upper.tree.flattened().vertices(at: upper.z)
        let allPoints = lowerPoints + upperPoints
        return allPoints.convexHull()
    }

    private static func resampledLoftSegment(resamplingLayers: [ResamplingLayer], in environment: EnvironmentValues) async -> any Geometry3D {
        var groups = buildPolygonGroups(layerTrees: resamplingLayers.map(\.tree))

        for (index, layerPolygons) in groups.enumerated() {
            // Determine target count based on longest perimeter
            let maxPerimeter = layerPolygons.polygons.map(\.perimeter).max()!

            let targetCount = environment.scaledSegmentation.segmentCount(length: maxPerimeter)
            var newPolygons = SimplePolygonList(layerPolygons.polygons.map {
                $0.resampled(count: targetCount)
            })

            // Align by minimizing total distance between consecutive layers
            newPolygons.alignOffsets()
            groups[index] = newPolygons
        }

        let interpolatedGroups = Self.interpolatePolygonGroups(for: groups, layers: resamplingLayers, environment: environment)
        return Mesh(polygonGroups: interpolatedGroups)
            .simplified()
    }
}
