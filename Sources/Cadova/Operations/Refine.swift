import Foundation
import Manifold3D

public extension Geometry3D {
    /// Refines the geometry by subdividing edges to ensure no edge exceeds the specified maximum length.
    ///
    /// This operation increases the density of the geometry by subdividing long edges or faces,
    /// ensuring that no edge is longer than the specified `maxEdgeLength`.
    /// It is useful for preparing geometry that needs higher resolution for operations like warping, wrapping, or other non-linear transformations.
    ///
    /// - Parameter maxEdgeLength: The maximum allowed length of any edge after refinement.
    /// - Returns: A new geometry with refined resolution.
    ///
    func refined(maxEdgeLength: Double) -> any Geometry3D {
        return CachingPrimitiveTransformer(body: self, name: "Cadova.Refine", parameters: maxEdgeLength) {
            $0.refine(edgeLength: maxEdgeLength)
        }
    }
}

public extension Geometry2D {
    /// Refines the 2D geometry by subdividing segments to ensure no segment exceeds the specified maximum length.
    ///
    /// This operation increases the point density of 2D shapes by adding intermediate points
    /// along segments that are longer than `maxSegmentLength`. This is particularly useful
    /// for preparing 2D geometries for operations like wrapping, offsetting, or detailed transformations.
    ///
    /// - Parameter maxSegmentLength: The maximum allowed length of any line segment after refinement.
    /// - Returns: A new, refined 2D geometry with uniformly shorter segments.
    ///
    func refined(maxSegmentLength: Double) -> any Geometry2D {
        CachingPrimitiveTransformer(body: self, name: "Cadova.Refine", parameters: maxSegmentLength) {
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
        CachingPrimitiveTransformer(body: self, name: "Cadova.Simplify", parameters: tolerance) { primitive in
            primitive.simplify(epsilon: tolerance)
        }
    }
}
