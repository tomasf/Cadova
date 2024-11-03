import Foundation

extension [Geometry2D]: Geometry2D {
    public func evaluated(in environment: Environment) -> Output2D {
        union(self).evaluated(in: environment)
    }
}

extension [Geometry3D]: Geometry3D {
    public func evaluated(in environment: Environment) -> Output3D {
        union(self).evaluated(in: environment)
    }
}
