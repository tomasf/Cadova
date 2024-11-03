import Foundation

public extension Geometry2D {
    func named(_ name: String) -> any Geometry2D {
        withResult(GeometryName(name))
    }
}

public extension Geometry3D {
    func named(_ name: String) -> any Geometry3D {
        withResult(GeometryName(name))
    }
}
