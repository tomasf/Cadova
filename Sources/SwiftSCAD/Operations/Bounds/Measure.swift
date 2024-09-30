import Foundation

struct ReadBoundary2D: Geometry2D {
    var body: any Geometry2D
    var builder: (Boundary2D) -> any Geometry2D

    func body(in environment: Environment) -> any Geometry2D {
        let boundary = body.boundary(in: environment)
        return builder(boundary)
    }

    func invocation(in environment: Environment) -> Invocation {
        body(in: environment).invocation(in: environment)
    }

    func boundary(in environment: Environment) -> Bounds {
        body(in: environment).boundary(in: environment)
    }

    func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        body(in: environment).anchors(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body(in: environment).elements(in: environment)
    }
}

struct ReadBoundary3D: Geometry3D {
    var body: any Geometry3D
    var builder: (Boundary3D) -> any Geometry3D

    func body(in environment: Environment) -> any Geometry3D {
        let boundary = body.boundary(in: environment)
        return builder(boundary)
    }

    func invocation(in environment: Environment) -> Invocation {
        body(in: environment).invocation(in: environment)
    }

    func boundary(in environment: Environment) -> Bounds {
        body(in: environment).boundary(in: environment)
    }

    func anchors(in environment: Environment) -> [Anchor: AffineTransform3D] {
        body(in: environment).anchors(in: environment)
    }

    func elements(in environment: Environment) -> [ObjectIdentifier: any ResultElement] {
        body(in: environment).elements(in: environment)
    }
}

public extension Geometry2D {
    /// Measures the bounding box of the 2D geometry and applies custom modifications based on the bounding box.
    ///
    /// - Parameter builder: A closure defining how to modify the geometry based on its bounding box.
    /// - Returns: A modified version of the original geometry.
    func measuringBounds(@UnionBuilder2D _ builder: @escaping (any Geometry2D, BoundingBox2D) -> any Geometry2D) -> any Geometry2D {
        ReadBoundary2D(body: self) { builder(self, $0.boundingBox ?? .zero) }
    }
}

public extension Geometry3D {
    /// Measures the bounding box of the 3D geometry and applies custom modifications based on the bounding box.
    ///
    /// - Parameter builder: A closure defining how to modify the geometry based on its bounding box.
    /// - Returns: A modified version of the original geometry.
    func measuringBounds(@UnionBuilder3D _ builder: @escaping (any Geometry3D, BoundingBox3D) -> any Geometry3D) -> any Geometry3D {
        ReadBoundary3D(body: self) { builder(self, $0.boundingBox ?? .zero) }
    }
}

public func measureBounds<V>(_ geometry: any Geometry2D, in environment: Environment = .defaultEnvironment, operation: (BoundingBox2D) -> V) -> V {
    operation(geometry.boundary(in: environment).boundingBox ?? .zero)
}

public func measureBounds<V>(_ geometry: any Geometry3D, in environment: Environment = .defaultEnvironment, operation: (BoundingBox3D) -> V) -> V {
    operation(geometry.boundary(in: environment).boundingBox ?? .zero)
}
