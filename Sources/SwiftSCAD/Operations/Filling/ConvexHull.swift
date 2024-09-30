import Foundation

struct ConvexHull2D: WrappedGeometry2D {
    let body: any Geometry2D

    let moduleName: String? = "hull"
}

struct ConvexHull3D: WrappedGeometry3D {
    let body: any Geometry3D

    let moduleName: String? = "hull"
}

public extension Geometry2D {
    /// Create a convex hull of this geometry in 2D space.
    ///
    /// A convex hull is the smallest convex shape that completely encloses the geometry. It is often visualized as the shape formed by stretching a rubber band to enclose the geometry.
    ///
    /// - Returns: A new geometry representing the convex hull of the original geometry.
    func convexHull() -> any Geometry2D {
        ConvexHull2D(body: self)
    }
}

public extension Geometry3D {
    /// Create a convex hull of this geometry in 3D space.
    ///
    /// A convex hull is the smallest convex shape that completely encloses the geometry. This can be likened to wrapping the geometry with a stretchable, shrinkable film that takes the shape of the geometry's outermost points.
    ///
    /// - Returns: A new geometry representing the convex hull of the original geometry.
    func convexHull() -> any Geometry3D {
        ConvexHull3D(body: self)
    }
}
