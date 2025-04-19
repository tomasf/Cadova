import Foundation
import Manifold3D

public extension Geometry {
    /// Create a convex hull of this geometry.
    ///
    /// A convex hull is the smallest convex shape that completely encloses the geometry. It is often visualized as the shape formed by stretching a rubber band to enclose the geometry.
    ///
    /// - Returns: A new geometry representing the convex hull of the original geometry.
    func convexHull() -> D.Geometry {
        GeometryExpressionTransformer(body: self) { .convexHull($0) }
    }
}
