import Foundation

struct ForceRender2D: WrappedGeometry2D {
    let body: any Geometry2D
    let convexity: Int
    
    let invocationName: String? = "render"
    var invocationParameters: Invocation.Parameters {
        ["convexity": convexity]
    }
}

struct ForceRender3D: WrappedGeometry3D {
    let body: any Geometry3D
    let convexity: Int
    
    let invocationName: String? = "render"
    var invocationParameters: Invocation.Parameters {
        ["convexity": convexity]
    }
}

public extension Geometry2D {
    /// Force rendering
    ///
    /// In preview mode, this operation forces the generation of a mesh for this geometry. This approach is useful for ensuring accurate previews of geometries, especially when boolean operations are complex and slow to compute. It also helps in avoiding or working around preview artifacts that might arise.
    ///
    /// - Parameters:
    ///   - convexity: The maximum number of surfaces a straight line can intersect the result. This helps OpenSCAD preview the geometry correctly, but has no effect on final rendering.
    func forceRendered(convexity: Int = 2) -> any Geometry2D {
        ForceRender2D(body: self, convexity: convexity)
    }
}

public extension Geometry3D {
    /// Force rendering
    ///
    /// In preview mode, this operation forces the generation of a mesh for this geometry. This approach is useful for ensuring accurate previews of geometries, especially when boolean operations are complex and slow to compute. It also helps in avoiding or working around preview artifacts that might arise.
    ///
    /// - Parameters:
    ///   - convexity: The maximum number of surfaces a straight line can intersect the result. This helps OpenSCAD preview the geometry correctly, but has no effect on final rendering.
    func forceRendered(convexity: Int = 2) -> any Geometry3D {
        ForceRender3D(body: self, convexity: convexity)
    }
}
