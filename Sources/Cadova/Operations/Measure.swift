import Foundation


fileprivate struct Measure<Input: Dimensionality, D: Dimensionality>: Geometry {
    let target: Input.Geometry
    let builder: @Sendable (Input.Geometry, Measurements<Input>) -> D.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        let targetResult = await target.build(in: environment, context: context)
        let expressionResult = await context.result(for: targetResult.expression)
        let generatedGeometry = builder(target, .init(primitive: expressionResult.primitive))
        return await generatedGeometry.build(in: environment, context: context)
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
