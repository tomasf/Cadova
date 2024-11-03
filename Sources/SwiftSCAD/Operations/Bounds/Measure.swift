import Foundation

fileprivate struct ReadBoundary<V: Vector> {
    let target: V.Geometry
    let builder: (Boundary<V>) -> V.Geometry

    @EnvironmentValue(\.self) var environment
}

extension ReadBoundary<Vector2D>: Geometry2D, Shape2D {
    var body: any Geometry2D {
        builder(target.evaluated(in: environment).boundary)
    }
}

extension ReadBoundary<Vector3D>: Geometry3D, Shape3D {
    var body: any Geometry3D {
        builder(target.evaluated(in: environment).boundary)
    }
}


internal extension Geometry2D {
    func readingBoundary(@GeometryBuilder2D _ builder: @escaping (any Geometry2D, Boundary2D) -> any Geometry2D) -> any Geometry2D {
        ReadBoundary(target: self) { boundary in
            builder(self, boundary)
        }
    }
}

internal extension Geometry3D {
    func readingBoundary(@GeometryBuilder3D _ builder: @escaping (any Geometry3D, Boundary3D) -> any Geometry3D) -> any Geometry3D {
        ReadBoundary(target: self) { boundary in
            builder(self, boundary)
        }
    }
}

public extension Geometry2D {
    /// Measures the bounding box of the 2D geometry and applies custom modifications based on the bounding box.
    ///
    /// - Parameter builder: A closure defining how to modify the geometry based on its bounding box.
    /// - Returns: A modified version of the original geometry.
    func measuringBounds(@GeometryBuilder2D _ builder: @escaping (any Geometry2D, BoundingBox2D?) -> any Geometry2D) -> any Geometry2D {
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
    func measuringBounds(@GeometryBuilder3D _ builder: @escaping (any Geometry3D, BoundingBox3D?) -> any Geometry3D) -> any Geometry3D {
        readingBoundary { geometry, boundary in
            builder(geometry, boundary.boundingBox)
        }
    }
}

public func measureBounds<V>(_ geometry: any Geometry2D, in environment: Environment = .defaultEnvironment, operation: (BoundingBox2D?) -> V) -> V {
    operation(geometry.evaluated(in: environment).boundary.boundingBox)
}

public func measureBounds<V>(_ geometry: any Geometry3D, in environment: Environment = .defaultEnvironment, operation: (BoundingBox3D?) -> V) -> V {
    operation(geometry.evaluated(in: environment).boundary.boundingBox)
}
