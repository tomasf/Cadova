import Foundation

struct ConvexHull2D: WrapperGeometry2D {
    let body: any Geometry2D

    var invocation: Invocation? {
        .init(name: "hull")
    }
}

struct ConvexHull3D: WrapperGeometry3D {
    let body: any Geometry3D

    var invocation: Invocation? {
        .init(name: "hull")
    }
}

public extension Geometry2D {
    /// The convex hull of this geometry
    ///
    /// A convex hull is the smallest convex shape that includes the geometry within it.

    func convexHull() -> any Geometry2D {
        ConvexHull2D(body: self)
    }
}

public extension Geometry3D {
    /// The convex hull of this geometry
    ///
    /// A convex hull is the smallest convex shape that includes the geometry within it.

    func convexHull() -> any Geometry3D {
        ConvexHull3D(body: self)
    }
}
