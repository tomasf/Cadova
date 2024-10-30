import Foundation

fileprivate struct ForceRender<Geometry> {
    let body: Geometry
    let moduleName: String? = "render"
}

extension ForceRender<any Geometry2D>: Geometry2D, WrappedGeometry2D {}
extension ForceRender<any Geometry3D>: Geometry3D, WrappedGeometry3D {}


public extension Geometry2D {
    /// Force rendering
    ///
    /// In preview mode, this operation forces the generation of a mesh for this geometry. This approach is useful for ensuring accurate previews of geometries, especially when boolean operations are complex and slow to compute. It also helps in avoiding or working around preview artifacts that might arise.
    ///
    func forceRendered() -> any Geometry2D {
        ForceRender(body: self)
    }
}

public extension Geometry3D {
    /// Force rendering
    ///
    /// In preview mode, this operation forces the generation of a mesh for this geometry. This approach is useful for ensuring accurate previews of geometries, especially when boolean operations are complex and slow to compute. It also helps in avoiding or working around preview artifacts that might arise.
    func forceRendered() -> any Geometry3D {
        ForceRender(body: self)
    }
}
