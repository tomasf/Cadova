import Foundation

struct ReadBoundary2D: Geometry2D {
    var body: any Geometry2D
    var builder: (any Geometry2D, Boundary2D) -> any Geometry2D

    func output(in environment: Environment) -> Output {
        let bodyOutput = body.output(in: environment)
        return builder(body, bodyOutput.boundary)
            .output(in: environment)
    }
}

struct ReadBoundary3D: Geometry3D {
    var body: any Geometry3D
    var builder: (any Geometry3D, Boundary3D) -> any Geometry3D

    func output(in environment: Environment) -> Output {
        let bodyOutput = body.output(in: environment)
        return builder(body, bodyOutput.boundary)
            .output(in: environment)
    }
}

public extension Geometry2D {
    func measuringBounds(@UnionBuilder2D _ builder: @escaping (any Geometry2D, BoundingBox2D) -> any Geometry2D) -> any Geometry2D {
        ReadBoundary2D(body: self, builder: { builder($0, $1.boundingBox) })
    }
}

public extension Geometry3D {
    func measuringBounds(@UnionBuilder3D _ builder: @escaping (any Geometry3D, BoundingBox3D) -> any Geometry3D) -> any Geometry3D {
        ReadBoundary3D(body: self, builder: { builder($0, $1.boundingBox) })
    }

    func visualizingBounds(scale: Double = 1.0) -> any Geometry3D {
        ReadBoundary3D(body: self) { geometry, boundary in
            Union {
                geometry
                boundary.visualized()
                boundary.boundingBox.visualized(borderWidth: 0.1)
            }
        }
    }
}
