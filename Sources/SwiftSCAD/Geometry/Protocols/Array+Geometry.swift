import Foundation

extension Array<Geometry2D>: Geometry2D {
    public func output(in environment: Environment) -> GeometryOutput2D {
        Union2D(children: self).output(in: environment)
    }
}

extension Array<Geometry3D>: Geometry3D {
    public func output(in environment: Environment) -> GeometryOutput3D {
        Union3D(children: self).output(in: environment)
    }
}
