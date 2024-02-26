import Foundation

struct Minkowski3D: CoreGeometry3D {
    let children: [any Geometry3D]

    func call(in environment: Environment) -> SCADCall {
        SCADCall(name: "minkowski", body: GeometrySequence(children: children))
    }
}

public extension Geometry3D {
    func minkowskiSum(@SequenceBuilder3D adding other: () -> [any Geometry3D]) -> any Geometry3D {
        Minkowski3D(children: [self] + other())
    }
}

struct Minkowski2D: CoreGeometry2D {
    let children: [any Geometry2D]

    func call(in environment: Environment) -> SCADCall {
        SCADCall(name: "minkowski", body: GeometrySequence(children: children))
    }
}

public extension Geometry2D {
    func minkowskiSum(@SequenceBuilder2D adding other: () -> [any Geometry2D]) -> any Geometry2D {
        Minkowski2D(children: [self] + other())
    }
}
