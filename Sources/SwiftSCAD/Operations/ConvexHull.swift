import Foundation

struct ConvexHull3D: CoreGeometry3D {
    let body: any Geometry3D

    func call(in environment: Environment) -> SCADCall {
        SCADCall(name: "hull", body: body)
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


struct ConvexHull2D: CoreGeometry2D {
    let body: any Geometry2D

    func call(in environment: Environment) -> SCADCall {
        SCADCall(name: "hull", body: body)
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
