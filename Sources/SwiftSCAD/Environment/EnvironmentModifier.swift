import Foundation

struct EnvironmentModifier2D: Geometry2D {
    let body: Geometry2D
    let modification: (Environment) -> Environment

    func scadString(in environment: Environment) -> String {
        body.scadString(in: modification(environment))
    }
}

struct EnvironmentModifier3D: Geometry3D {
    let body: Geometry3D
    let modification: (Environment) -> Environment

    func scadString(in environment: Environment) -> String {
        body.scadString(in: modification(environment))
    }
}

public extension Geometry2D {
    func withEnvironment(_ modifier: @escaping (Environment) -> Environment) -> Geometry2D {
        EnvironmentModifier2D(body: self, modification: modifier)
    }

    internal func withEnvironment(_ environment: Environment) -> Geometry2D {
        withEnvironment { _ in environment }
    }
}

public extension Geometry3D {
    func withEnvironment(_ modifier: @escaping (Environment) -> Environment) -> Geometry3D {
        EnvironmentModifier3D(body: self, modification: modifier)
    }

    internal func withEnvironment(_ environment: Environment) -> Geometry3D {
        withEnvironment { _ in environment }
    }
}
