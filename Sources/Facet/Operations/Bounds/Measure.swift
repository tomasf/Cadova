import Foundation

fileprivate struct ReadBoundary<D: Dimensionality> {
    let target: D.Geometry
    let builder: (D.Geometry, BoundingBox<D.Vector>) -> D.Geometry
}

extension ReadBoundary<Dimensionality2>: Geometry2D {
    func evaluated(in environment: EnvironmentValues) -> Output2D {
        let output = target.evaluated(in: environment)
        return builder(StaticGeometry(output: output), .init(output.manifold.boundingBox))
            .evaluated(in: environment)
    }
}

extension ReadBoundary<Dimensionality3>: Geometry3D {
    func evaluated(in environment: EnvironmentValues) -> Output3D {
        let output = target.evaluated(in: environment)
        return builder(StaticGeometry(output: output), .init(output.manifold.boundingBox))
            .evaluated(in: environment)
    }
}


internal extension Geometry2D {
    func readingBoundary(@GeometryBuilder2D _ builder: @escaping (any Geometry2D, BoundingBox2D) -> any Geometry2D) -> any Geometry2D {
        ReadBoundary(target: self) { geometry, boundary in
            builder(geometry, boundary)
        }
    }
}

internal extension Geometry3D {
    func readingBoundary(@GeometryBuilder3D _ builder: @escaping (any Geometry3D, BoundingBox3D) -> any Geometry3D) -> any Geometry3D {
        ReadBoundary(target: self) { geometry, boundary in
            builder(geometry, boundary)
        }
    }
}

public extension Geometry2D {
    /// Measures the bounding box of the 2D geometry and applies custom modifications based on the bounding box.
    ///
    /// - Parameter builder: A closure defining how to modify the geometry based on its bounding box.
    /// - Returns: A modified version of the original geometry.
    func measuringBounds(@GeometryBuilder2D _ builder: @escaping (any Geometry2D, BoundingBox2D?) -> any Geometry2D) -> any Geometry2D {
        readingBoundary { geometry, boundingBox in
            builder(geometry, boundingBox)
        }
    }
}

public extension Geometry3D {
    /// Measures the bounding box of the 3D geometry and applies custom modifications based on the bounding box.
    ///
    /// - Parameter builder: A closure defining how to modify the geometry based on its bounding box.
    /// - Returns: A modified version of the original geometry.
    func measuringBounds(@GeometryBuilder3D _ builder: @escaping (any Geometry3D, BoundingBox3D?) -> any Geometry3D) -> any Geometry3D {
        readingBoundary { geometry, boundingBox in
            builder(geometry, boundingBox)
        }
    }
}

public func measureBounds<V>(_ geometry: any Geometry2D, in environment: EnvironmentValues = .defaultEnvironment, operation: (BoundingBox2D?) -> V) -> V {
    operation(.init(geometry.evaluated(in: environment).manifold.boundingBox))
}

public func measureBounds<V>(_ geometry: any Geometry3D, in environment: EnvironmentValues = .defaultEnvironment, operation: (BoundingBox3D?) -> V) -> V {
    operation(.init(geometry.evaluated(in: environment).manifold.boundingBox))
}
