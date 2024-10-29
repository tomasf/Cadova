import Foundation

public extension Geometry2D {
    func replaced(@GeometryBuilder2D with replacement: (_ input: any Geometry2D) -> any Geometry2D) -> any Geometry2D {
        replacement(self)
    }
}

public extension Geometry3D {
    func replaced(@GeometryBuilder3D with replacement: (_ input: any Geometry3D) -> any Geometry3D) -> any Geometry3D {
        replacement(self)
    }
}
