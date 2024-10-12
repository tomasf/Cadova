import Foundation

fileprivate struct ReadBoundary2D: Shape2D {
    let target: any Geometry2D
    let builder: (Boundary2D) -> any Geometry2D

    var body: any Geometry2D {
        EnvironmentReader { environment in
            builder(target.boundary(in: environment))
        }
    }
}

fileprivate struct ReadBoundary3D: Shape3D {
    let target: any Geometry3D
    let builder: (Boundary3D) -> any Geometry3D

    var body: any Geometry3D {
        EnvironmentReader { environment in
            builder(target.boundary(in: environment))
        }
    }
}

internal extension Geometry2D {
    func readingBoundary(@UnionBuilder2D _ builder: @escaping (any Geometry2D, Boundary2D) -> any Geometry2D) -> any Geometry2D {
        ReadBoundary2D(target: self) { boundary in
            builder(self, boundary)
        }
    }
}

internal extension Geometry3D {
    func readingBoundary(@UnionBuilder3D _ builder: @escaping (any Geometry3D, Boundary3D) -> any Geometry3D) -> any Geometry3D {
        ReadBoundary3D(target: self) { boundary in
            builder(self, boundary)
        }
    }
}

public extension Geometry2D {
    /// Measures the bounding box of the 2D geometry and applies custom modifications based on the bounding box.
    ///
    /// - Parameter builder: A closure defining how to modify the geometry based on its bounding box.
    /// - Returns: A modified version of the original geometry.
    func measuringBounds(@UnionBuilder2D _ builder: @escaping (any Geometry2D, BoundingBox2D?) -> any Geometry2D) -> any Geometry2D {
        readingBoundary { geometry, boundary in
            builder(geometry, boundary.boundingBox)
        }
    }
}

public extension Geometry3D {
    /// Measures the bounding box of the 3D geometry and applies custom modifications based on the bounding box.
    ///
    /// - Parameter builder: A closure defining how to modify the geometry based on its bounding box.
    /// - Returns: A modified version of the original geometry.
    func measuringBounds(@UnionBuilder3D _ builder: @escaping (any Geometry3D, BoundingBox3D?) -> any Geometry3D) -> any Geometry3D {
        readingBoundary { geometry, boundary in
            builder(geometry, boundary.boundingBox)
        }
    }
}

public func measureBounds<V>(_ geometry: any Geometry2D, in environment: Environment = .defaultEnvironment, operation: (BoundingBox2D?) -> V) -> V {
    operation(geometry.boundary(in: environment).boundingBox)
}

public func measureBounds<V>(_ geometry: any Geometry3D, in environment: Environment = .defaultEnvironment, operation: (BoundingBox3D?) -> V) -> V {
    operation(geometry.boundary(in: environment).boundingBox)
}
