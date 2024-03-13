import Foundation

internal struct EnvironmentReader2D: Geometry2D {
    let body: (Environment) -> any Geometry2D

    func output(in environment: Environment) -> GeometryOutput2D {
        body(environment).output(in: environment)
    }
}

internal struct EnvironmentReader3D: Geometry3D {
    let body: (Environment) -> any Geometry3D

    func output(in environment: Environment) -> GeometryOutput3D {
        body(environment).output(in: environment)
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
