import Foundation

internal struct EnvironmentReader2D: ContainerGeometry2D {
    let body: (Environment) -> any Geometry2D

    func geometry(in environment: Environment) -> any Geometry2D {
        body(environment)
    }
}

internal struct EnvironmentReader3D: ContainerGeometry3D {
    let body: (Environment) -> any Geometry3D

    func geometry(in environment: Environment) -> any Geometry3D {
        body(environment)
    }
}

public func EnvironmentReader(@UnionBuilder2D body: @escaping (Environment) -> any Geometry2D) -> any Geometry2D {
    EnvironmentReader2D(body: body)
}

public func EnvironmentReader(@UnionBuilder3D body: @escaping (Environment) -> any Geometry3D) -> any Geometry3D {
    EnvironmentReader3D(body: body)
}

public extension Geometry2D {
    func readingEnvironment(@UnionBuilder2D _ body: @escaping (any Geometry2D, Environment) -> any Geometry2D) -> any Geometry2D {
        EnvironmentReader2D { environment in
            body(self, environment)
        }
    }
}

public extension Geometry3D {
    func readingEnvironment(@UnionBuilder3D _ body: @escaping (any Geometry3D, Environment) -> any Geometry3D) -> any Geometry3D {
        EnvironmentReader3D { environment in
            body(self, environment)
        }
    }
}
