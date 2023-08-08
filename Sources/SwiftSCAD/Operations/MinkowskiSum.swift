import Foundation

struct Minkowski3D: CoreGeometry3D {
    let children: [Geometry3D]

    func call(in environment: Environment) -> SCADCall {
        SCADCall(name: "minkowski", body: GeometrySequence(children: children))
    }
}

public func MinkowskiSum(@SequenceBuilder3D components: () -> [Geometry3D]) -> Geometry3D {
    Minkowski3D(children: components())
}

public extension Geometry3D {
    func minkowskiSum(@SequenceBuilder3D with other: () -> [Geometry3D]) -> Geometry3D {
        Minkowski3D(children: [self] + other())
    }
}


struct Minkowski2D: CoreGeometry2D {
    let children: [Geometry2D]

    func call(in environment: Environment) -> SCADCall {
        SCADCall(name: "minkowski", body: GeometrySequence(children: children))
    }
}

public func MinkowskiSum(@SequenceBuilder2D components: () -> [Geometry2D]) -> Geometry2D {
    Minkowski2D(children: components())
}

public extension Geometry2D {
    func minkowskiSum(@SequenceBuilder2D with other: () -> [Geometry2D]) -> Geometry2D {
        Minkowski2D(children: [self] + other())
    }
}
