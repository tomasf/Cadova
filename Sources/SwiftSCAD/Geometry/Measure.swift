import Foundation

struct ReadBoundary2D: Geometry2D {
    var body: any Geometry2D
    var builder: (any Geometry2D, Boundary2D) -> any Geometry2D

    func output(in environment: Environment) -> GeometryOutput2D {
        let bodyOutput = body.output(in: environment)
        let localBoundary = bodyOutput.boundary
        return builder(body, localBoundary)
            .output(in: environment)
    }
}

struct ReadBoundary3D: Geometry3D {
    var body: any Geometry3D
    var builder: (any Geometry3D, Boundary3D) -> any Geometry3D

    func output(in environment: Environment) -> GeometryOutput3D {
        let bodyOutput = body.output(in: environment)
        let localBoundary = bodyOutput.boundary
        return builder(body, localBoundary)
            .output(in: environment)
    }
}

public extension Geometry2D {
    func measuringBounds(@UnionBuilder2D _ builder: @escaping (any Geometry2D, BoundingBox2D) -> any Geometry2D) -> any Geometry2D {
        ReadBoundary2D(body: self, builder: { builder($0, $1.boundingBox ?? .zero) })
    }
}

public extension Geometry3D {
    func measuringBounds(@UnionBuilder3D _ builder: @escaping (any Geometry3D, BoundingBox3D) -> any Geometry3D) -> any Geometry3D {
        ReadBoundary3D(body: self, builder: { builder($0, $1.boundingBox ?? .zero) })
    }
}
