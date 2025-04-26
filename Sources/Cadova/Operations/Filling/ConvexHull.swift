import Foundation
import Manifold3D

public extension Geometry {
    /// Returns the convex hull of this geometry.
    ///
    /// A convex hull is the smallest convex shape that entirely contains the geometry.
    /// It can be visualized as the shape formed by wrapping a rubber band around the outermost points of the geometry.
    ///
    /// This operation is useful for simplifying complex shapes or enclosing loose collections of geometry.
    ///
    /// - Returns: A new geometry representing the convex hull of the original shape.
    ///
    func convexHull() -> D.Geometry {
        GeometryExpressionTransformer(body: self) { .convexHull($0) }
    }

    /// Returns the convex hull of this geometry, including additional points.
    ///
    /// This variant of the convex hull operation extends the result to also include
    /// the specified points. The combined set of the geometry’s vertices and the provided points
    /// are used to compute the hull.
    ///
    /// - Parameter points: Additional points to include in the hull calculation.
    /// - Returns: A new geometry representing the convex hull of the combined shape and points.
    ///
    func convexHull(adding points: [D.Vector]) -> D.Geometry {
        CachingPrimitiveTransformer(body: self, name: "Cadova.Hull", parameters: points) {
            .hull($0.allVertices() + points)
        }
    }

    /// Returns the convex hull of this geometry, including additional points.
    ///
    /// This variant of the convex hull operation extends the result to also include
    /// the specified points. The combined set of the geometry’s vertices and the provided points
    /// are used to compute the hull.
    ///
    /// - Parameter points: Additional points to include in the hull calculation.
    /// - Returns: A new geometry representing the convex hull of the combined shape and points.
    ///
    func convexHull(adding points: D.Vector...) -> D.Geometry {
        convexHull(adding: points)
    }
}
