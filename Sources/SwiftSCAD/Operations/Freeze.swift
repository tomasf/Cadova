import Foundation

struct FrozenGeometry2D: Geometry2D {
    let output: GeometryOutput2D

    func output(in environment: Environment) -> Output {
        output
    }
}

struct FrozenGeometry3D: Geometry3D {
    let output: GeometryOutput3D

    func output(in environment: Environment) -> Output {
        output
    }
}

public extension Geometry2D {
    func frozen() -> any Geometry2D {
        EnvironmentReader { environment in
            FrozenGeometry2D(output: self.output(in: environment))
        }
    }
}

public extension Geometry3D {
    func frozen() -> any Geometry3D {
        EnvironmentReader { environment in
            FrozenGeometry3D(output: self.output(in: environment))
        }
    }
}
