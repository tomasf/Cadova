import Foundation

struct EnvironmentModifier2D: WrappedGeometry2D {
    let body: any Geometry2D
    let modification: (Environment) -> Environment
    let invocation: Invocation? = nil

    func modifiedEnvironment(_ environment: Environment) -> Environment {
        modification(environment)
    }
}

struct EnvironmentModifier3D: WrappedGeometry3D {
    let body: any Geometry3D
    let modification: (Environment) -> Environment
    let invocation: Invocation? = nil

    func modifiedEnvironment(_ environment: Environment) -> Environment {
        modification(environment)
    }
}

public extension Geometry2D {
    func withEnvironment(_ modifier: @escaping (Environment) -> Environment) -> any Geometry2D {
        EnvironmentModifier2D(body: self, modification: modifier)
    }

    internal func withEnvironment(_ environment: Environment) -> any Geometry2D {
        withEnvironment { _ in environment }
    }
}

public extension Geometry3D {
    func withEnvironment(_ modifier: @escaping (Environment) -> Environment) -> any Geometry3D {
        EnvironmentModifier3D(body: self, modification: modifier)
    }

    internal func withEnvironment(_ environment: Environment) -> any Geometry3D {
        withEnvironment { _ in environment }
    }
}
