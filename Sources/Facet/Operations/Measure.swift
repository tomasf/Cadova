import Foundation


fileprivate struct Measure<D: Dimensionality> {
    let target: D.Geometry
    let builder: (D.Geometry, Measurements<D>) -> D.Geometry
}

extension Measure<Dimensionality2>: Geometry2D {
    func evaluated(in environment: EnvironmentValues) -> Output2D {
        let output = target.evaluated(in: environment)
        return builder(StaticGeometry(output: output), .init(primitive: output.primitive))
            .evaluated(in: environment)
    }
}

extension Measure<Dimensionality3>: Geometry3D {
    func evaluated(in environment: EnvironmentValues) -> Output3D {
        let output = target.evaluated(in: environment)
        return builder(StaticGeometry(output: output), .init(primitive: output.primitive))
            .evaluated(in: environment)
    }
}


public extension Geometry2D {
    /// Applies custom modifications to a geometry based on its measured properties.
    ///
    /// This method evaluates the geometry and passes its measurements, such as area and bounding box, to a closure.
    /// The closure can then return a modified geometry based on these measurements.
    ///
    /// - Parameter builder: A closure that accepts the current geometry and its measurements,
    ///   and returns a modified geometry.
    /// - Returns: A new geometry resulting from the builder's modifications.
    func measuring(@GeometryBuilder2D _ builder: @escaping (any Geometry2D, Measurements2D) -> any Geometry2D) -> any Geometry2D {
        Measure(target: self) { geometry, boundary in
            builder(geometry, boundary)
        }
    }
}

public extension Geometry3D {
    /// Applies custom modifications to a geometry based on its measured properties.
    ///
    /// This method evaluates the geometry and passes its measurements, such as volume, surface area, and bounding box, to a closure.
    /// The closure can then return a modified geometry based on these measurements.
    ///
    /// - Parameter builder: A closure that accepts the current geometry and its measurements,
    ///   and returns a modified geometry.
    /// - Returns: A new geometry resulting from the builder's modifications.
    func measuring(@GeometryBuilder3D _ builder: @escaping (any Geometry3D, Measurements3D) -> any Geometry3D) -> any Geometry3D {
        Measure(target: self) { geometry, boundary in
            builder(geometry, boundary)
        }
    }
}

internal extension Geometry2D {
    func measureBoundsIfNonEmpty(@GeometryBuilder2D _ builder: @escaping (any Geometry2D, BoundingBox2D) -> any Geometry2D) -> any Geometry2D {
        measuring { geometry, measurements in
            if let box = measurements.boundingBox {
                builder(geometry, box)
            } else {
                Empty()
            }
        }
    }
}

internal extension Geometry3D {
    func measureBoundsIfNonEmpty(@GeometryBuilder3D _ builder: @escaping (any Geometry3D, BoundingBox3D) -> any Geometry3D) -> any Geometry3D {
        measuring { geometry, measurements in
            if let box = measurements.boundingBox {
                builder(geometry, box)
            } else {
                Empty()
            }
        }
    }
}
