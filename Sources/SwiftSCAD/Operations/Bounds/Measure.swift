import Foundation

struct ReadBoundary2D: Geometry2D {
    var body: any Geometry2D
    var builder: (GeometrySnapshot2D, Boundary2D) -> any Geometry2D

    func output(in environment: Environment) -> GeometryOutput2D {
        let bodyOutput = body.output(in: environment)
        let localBoundary = bodyOutput.boundary
        return builder(GeometrySnapshot2D(source: body, output: bodyOutput), localBoundary)
            .output(in: environment)
    }
}

struct ReadBoundary3D: Geometry3D {
    var body: any Geometry3D
    var builder: (GeometrySnapshot3D, Boundary3D) -> any Geometry3D

    func output(in environment: Environment) -> GeometryOutput3D {
        let bodyOutput = body.output(in: environment)
        let localBoundary = bodyOutput.boundary
        return builder(GeometrySnapshot3D(source: body, output: bodyOutput), localBoundary)
            .output(in: environment)
    }
}

public extension Geometry2D {
    /// Measures the bounding box of the 2D geometry and applies custom modifications based on the bounding box.
    ///
    /// - Parameter builder: A closure defining how to modify the geometry based on its bounding box.
    /// - Returns: A modified version of the original geometry.
    func measuringBounds(@UnionBuilder2D _ builder: @escaping (GeometrySnapshot2D, BoundingBox2D) -> any Geometry2D) -> any Geometry2D {
        ReadBoundary2D(body: self, builder: { builder($0, $1.boundingBox ?? .zero) })
    }
}

public extension Geometry3D {
    /// Measures the bounding box of the 3D geometry and applies custom modifications based on the bounding box.
    ///
    /// - Parameter builder: A closure defining how to modify the geometry based on its bounding box.
    /// - Returns: A modified version of the original geometry.
    func measuringBounds(@UnionBuilder3D _ builder: @escaping (GeometrySnapshot3D, BoundingBox3D) -> any Geometry3D) -> any Geometry3D {
        ReadBoundary3D(body: self, builder: { builder($0, $1.boundingBox ?? .zero) })
    }
}
