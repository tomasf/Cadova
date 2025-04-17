import Foundation

extension [Geometry2D]: Geometry2D {
    public func evaluated(in environment: EnvironmentValues) -> GeometryResult2D {
        Union(children: self).evaluated(in: environment)
    }
}

extension [Geometry3D]: Geometry3D {
    public func evaluated(in environment: EnvironmentValues) -> GeometryResult3D {
        Union(children: self).evaluated(in: environment)
    }
}
