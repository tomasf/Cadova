import Foundation


fileprivate struct Measure<Input: Dimensionality, D: Dimensionality>: Geometry {
    let target: Input.Geometry
    let builder: @Sendable (Input.Geometry, Measurements<Input>) -> D.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let concreteResult = try await context.result(for: target, in: environment)
        let generatedGeometry = builder(target, .init(concrete: concreteResult.concrete))
        return try await context.buildResult(for: generatedGeometry, in: environment)
    }
}

public extension Geometry {
    /// Applies custom modifications to a geometry based on its measured properties.
    ///
    /// This method evaluates the geometry and passes its measurements, such as area/volume and bounding box, to a closure.
    /// The closure can then return a modified geometry based on these measurements.
    ///
    /// - Parameter builder: A closure that accepts the current geometry and its measurements,
    ///   and returns a modified geometry.
    /// - Returns: A new geometry resulting from the builder's modifications.
    func measuring<Output: Dimensionality>(
        @GeometryBuilder<Output> _ builder: @Sendable @escaping (D.Geometry, D.Measurements) -> Output.Geometry
    ) -> Output.Geometry {
        Measure(target: self, builder: builder)
    }

    /// Measures the geometry and provides a bounding box to a closure, if available.
    ///
    /// This is a convenience method for cases where you only need the bounding box
    /// of a geometry and want to avoid dealing with optionals.
    ///
    /// If the geometry has a bounding box (i.e., it's not empty), it is passed to the closure
    /// along with the geometry itself. If the geometry is empty and has no bounds,
    /// the method just produces an empty geometry.
    ///
    /// - Parameter builder: A closure that receives the geometry and its bounding box,
    ///   and returns a new geometry.
    /// - Returns: A modified geometry based on the bounding box, or an empty geometry if none exists.
    ///
    func measuringBounds<Output: Dimensionality>(
        @GeometryBuilder<Output> _ builder: @Sendable @escaping (D.Geometry, D.BoundingBox) -> Output.Geometry
    ) -> Output.Geometry {
        measuring { geometry, measurements in
            if let box = measurements.boundingBox {
                builder(geometry, box)
            } else {
                Empty()
            }
        }
    }
}

internal extension Geometry {
    func measureBoundsIfNonEmpty<Output: Dimensionality>(
        @GeometryBuilder<Output> _ builder: @Sendable @escaping (D.Geometry, EnvironmentValues, D.BoundingBox) -> Output.Geometry
    ) -> Output.Geometry {
        readEnvironment { environment in
            measuring { geometry, measurements in
                if let box = measurements.boundingBox {
                    builder(geometry, environment, box)
                } else {
                    Empty()
                }
            }
        }
    }
}
