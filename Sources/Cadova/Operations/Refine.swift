import Foundation
import Manifold3D

internal struct RefineCacheKey: CacheKey {
    let maxEdgeLength: Double
}

public extension Geometry3D {
    func refined(maxEdgeLength: Double) -> any Geometry3D {
        return CachingPrimitiveTransformer(body: self, key: RefineCacheKey(maxEdgeLength: maxEdgeLength)) {
            $0.refine(edgeLength: maxEdgeLength)
        }
    }
}

public extension Geometry2D {
    func refined(maxSegmentLength: Double) -> any Geometry2D {
        CachingPrimitiveTransformer(body: self, key: RefineCacheKey(maxEdgeLength: maxSegmentLength)) {
            let inputPoints: [[Vector2D]] = $0.polygons().map { $0.vertices.map(\.vector2D) }

            let newPoints = inputPoints.map { points in
                [points[0]] + points.paired().flatMap { from, to -> [Vector2D] in
                    let length = from.distance(to: to)
                    let segmentCount = ceil(length / maxSegmentLength)
                    guard segmentCount > 1 else { return [to] }
                    return (1...Int(segmentCount)).map { i in
                        from.point(alongLineTo: to, at: Double(i) / Double(segmentCount))
                    }
                }
            }
            return .init(polygons: newPoints.map { Manifold3D.Polygon(vertices: $0) }, fillRule: .nonZero)
        }
    }
}

internal struct SimplifyCacheKey: CacheKey {
    let epsilon: Double
}

public extension Geometry {
    /// Returns a simplified version of the geometry by reducing unnecessary detail.
    ///
    /// This operation removes redundant vertices or triangles from the geometry, based on the specified `epsilon` threshold.
    /// Vertices that are closer together than `epsilon`, or that are nearly collinear with their neighbors, are candidates for removal.
    /// Increasing the `epsilon` value makes the simplification more aggressive, potentially removing more features at the cost of fidelity.
    ///
    /// Applying simplification can significantly improve performance for subsequent operations by reducing complexity without noticeably altering the shape.
    ///
    /// - Parameters:
    ///   - tolerance: The minimum distance threshold for simplification. Smaller values preserve more detail; larger values produce simpler geometry.
    ///
    /// - Returns:
    ///   A new, simplified geometry instance.
    ///
    func simplified(tolerance: Double) -> D.Geometry {
        CachingPrimitiveTransformer(body: self, key: SimplifyCacheKey(epsilon: tolerance)) { primitive in
            primitive.simplify(epsilon: tolerance)
        }
    }
}
