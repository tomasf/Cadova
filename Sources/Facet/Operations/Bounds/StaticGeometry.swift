import Foundation

internal struct StaticGeometry<D: Dimensionality> {
    let output: Output<D>
}

extension StaticGeometry: Geometry2D where D == Dimensionality2 {
    func evaluated(in environment: EnvironmentValues) -> Output2D { output }
}

extension StaticGeometry: Geometry3D where D == Dimensionality3 {
    func evaluated(in environment: EnvironmentValues) -> Output3D { output }
}

extension Geometry2D {
    func statically(@GeometryBuilder2D _ action: @escaping (any Geometry2D) -> any Geometry2D) -> any Geometry2D {
        readEnvironment { environment in
            let staticGeometry = StaticGeometry(output: self.evaluated(in: environment))
            return action(staticGeometry)
        }
    }

    func statically(@GeometryBuilder3D _ action: @escaping (any Geometry2D) -> any Geometry3D) -> any Geometry3D {
        readEnvironment { environment in
            let staticGeometry = StaticGeometry(output: self.evaluated(in: environment))
            return action(staticGeometry)
        }
    }
}

extension Geometry3D {
    func statically(@GeometryBuilder3D _ action: @escaping (any Geometry3D) -> any Geometry3D) -> any Geometry3D {
        readEnvironment { environment in
            let staticGeometry = StaticGeometry(output: self.evaluated(in: environment))
            return action(staticGeometry)
        }
    }
}
