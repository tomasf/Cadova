import Foundation

public extension Geometry2D {
    func cloned(@UnionBuilder2D _ transform: (any Geometry2D) -> any Geometry2D) -> any Geometry2D {
        adding(transform(self))
    }
}

public extension Geometry3D {
    func cloned(@UnionBuilder3D _ transform: (any Geometry3D) -> any Geometry3D) -> any Geometry3D {
        adding(transform(self))
    }
}
