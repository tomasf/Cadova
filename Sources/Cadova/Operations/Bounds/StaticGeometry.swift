import Foundation

internal struct StaticGeometry<D: Dimensionality> {
    let output: GeometryResult<D>
}

extension StaticGeometry: Geometry2D where D == D2 {
    func evaluated(in environment: EnvironmentValues) -> GeometryResult2D { output }
}

extension StaticGeometry: Geometry3D where D == D3 {
    func evaluated(in environment: EnvironmentValues) -> GeometryResult3D { output }
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

extension D2.Primitive {
    func geometry(with elements: ResultElementsByType) -> any Geometry2D {
        StaticGeometry(output: GeometryResult2D(primitive: self, elements: elements))
    }
}

extension D3.Primitive {
    func geometry(with elements: ResultElementsByType) -> any Geometry3D {
        StaticGeometry(output: GeometryResult3D(primitive: self, elements: elements))
    }
}
