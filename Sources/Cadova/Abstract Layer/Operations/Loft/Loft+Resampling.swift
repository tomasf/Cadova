import Foundation
import Manifold3D

internal extension Loft {
    struct ResamplingSection {
        let distance: Double
        let transition: Transition
        let tree: PolygonTree

        var shapingFunction: ShapingFunction? {
            if case .interpolated(let function) = transition {
                return function
            }
            return nil
        }
    }

    static func resampledLoft(resamplingSections: [ResamplingSection], frames: [ParametricCurveFrame], in environment: EnvironmentValues, context: EvaluationContext) async -> any Geometry3D {
        // Find segments that use convex hull transitions
        var convexHullSegments: [(lowerIndex: Int, upperIndex: Int)] = []
        var interpolatedRanges: [Range<Int>] = []
        var currentRangeStart = 0

        for i in 1..<resamplingSections.count {
            if case .convexHull = resamplingSections[i].transition {
                // End the current interpolated range if it has at least 2 sections
                if i > currentRangeStart {
                    interpolatedRanges.append(currentRangeStart..<i)
                }
                convexHullSegments.append((i - 1, i))
                currentRangeStart = i
            }
        }

        // Add the final interpolated range
        if resamplingSections.count > currentRangeStart {
            interpolatedRanges.append(currentRangeStart..<resamplingSections.count)
        }

        // Build geometry for each segment
        var geometries: [any Geometry3D] = []

        // Process interpolated ranges
        for range in interpolatedRanges {
            if range.count >= 2 {
                let segmentSections = Array(resamplingSections[range])
                let geometry = await resampledLoftSegment(resamplingSections: segmentSections, frames: frames, in: environment)
                geometries.append(geometry)
            }
        }

        // Process convex hull segments
        for (lowerIndex, upperIndex) in convexHullSegments {
            let lowerSection = resamplingSections[lowerIndex]
            let upperSection = resamplingSections[upperIndex]
            let geometry = convexHullSegment(lower: lowerSection, upper: upperSection, frames: frames)
            geometries.append(geometry)
        }

        return Union(geometries)
    }

    private static func convexHullSegment(lower: ResamplingSection, upper: ResamplingSection, frames: [ParametricCurveFrame]) -> any Geometry3D {
        // Collect all vertices from both sections at their respective path transforms
        let lowerTransform = frames.binarySearchInterpolate(target: lower.distance, key: \.distance, result: \.transform)
        let upperTransform = frames.binarySearchInterpolate(target: upper.distance, key: \.distance, result: \.transform)
        let lowerPoints = lower.tree.flattened().vertices(transformedBy: lowerTransform)
        let upperPoints = upper.tree.flattened().vertices(transformedBy: upperTransform)
        let allPoints = lowerPoints + upperPoints
        return allPoints.convexHull()
    }

    private static func resampledLoftSegment(resamplingSections: [ResamplingSection], frames: [ParametricCurveFrame], in environment: EnvironmentValues) async -> any Geometry3D {
        var groups = buildPolygonGroups(layerTrees: resamplingSections.map(\.tree))

        for (index, layerPolygons) in groups.enumerated() {
            // Determine target count based on longest perimeter
            let maxPerimeter = layerPolygons.polygons.map(\.perimeter).max()!

            let targetCount = environment.scaledSegmentation.segmentCount(length: maxPerimeter)
            var newPolygons = SimplePolygonList(layerPolygons.polygons.map {
                $0.resampled(count: targetCount)
            })

            // Align by minimizing total distance between consecutive sections
            newPolygons.alignOffsets()
            groups[index] = newPolygons
        }

        let interpolatedGroups = Self.interpolatePolygonGroups(for: groups, sections: resamplingSections, frames: frames, environment: environment)
        return Mesh(polygonGroups: interpolatedGroups)
            .simplified()
    }
}
