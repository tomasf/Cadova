import Foundation

struct Minkowski2D: Geometry2D {
    let children: [any Geometry2D]

    func output(in environment: Environment) -> Output {
        .init(
            invocation: .init(name: "minkowski"),
            body: children,
            environment: environment
        )
    }
}

struct Minkowski3D: Geometry3D {
    let children: [any Geometry3D]

    func output(in environment: Environment) -> Output {
        .init(
            invocation: .init(name: "minkowski"),
            body: children,
            environment: environment
        )
    }
}

public extension Geometry3D {
    func minkowskiSum(@SequenceBuilder3D adding other: () -> [any Geometry3D]) -> any Geometry3D {
        Minkowski3D(children: [self] + other())
    }
}

public extension Geometry2D {
    func minkowskiSum(@SequenceBuilder2D adding other: () -> [any Geometry2D]) -> any Geometry2D {
        Minkowski2D(children: [self] + other())
    }
}
