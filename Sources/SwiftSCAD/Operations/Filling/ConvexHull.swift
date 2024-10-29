import Foundation

fileprivate struct ConvexHull<Geometry> {
    let body: Geometry
    let moduleName: String? = "hull"
}

extension ConvexHull<Geometry2D>: Geometry2D, WrappedGeometry2D {}
extension ConvexHull<Geometry3D>: Geometry3D, WrappedGeometry3D {}


public extension Geometry2D {
    /// Create a convex hull of this geometry in 2D space.
    ///
    /// A convex hull is the smallest convex shape that completely encloses the geometry. It is often visualized as the shape formed by stretching a rubber band to enclose the geometry.
    ///
    /// - Returns: A new geometry representing the convex hull of the original geometry.
    func convexHull() -> any Geometry2D {
        ConvexHull(body: self)
    }
}

public extension Geometry3D {
    /// Create a convex hull of this geometry in 3D space.
    ///
    /// A convex hull is the smallest convex shape that completely encloses the geometry. This can be likened to wrapping the geometry with a stretchable, shrinkable film that takes the shape of the geometry's outermost points.
    ///
    /// - Returns: A new geometry representing the convex hull of the original geometry.
    func convexHull() -> any Geometry3D {
        ConvexHull(body: self)
    }
}
