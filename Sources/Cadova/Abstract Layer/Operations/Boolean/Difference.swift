import Foundation
import Manifold3D

fileprivate struct Difference<D: Dimensionality>: Geometry {
    let positive: @Sendable () -> D.Geometry
    let negative: @Sendable () -> D.Geometry

    public func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        async let base = try await context.buildResult(for: positive(), in: environment)
        async let subtraction = try await context.buildResult(for: negative(), in: environment.invertingOperation())
        return try await .init(combining: [base, subtraction], operationType: .difference)
    }
}

public extension Geometry {
    /// Subtract other geometry from this geometry
    ///
    /// ## Example
    /// ```swift
    /// Rectangle([10, 10])
    ///     .subtracting {
    ///        Circle(diameter: 4)
    ///     }
    /// ```
    /// ```swift
    /// Box([10, 10, 5])
    ///     .subtracting {
    ///        Cylinder(diameter: 4, height: 3)
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - negative: The negative geometry to subtract
    /// - Returns: The new geometry

    func subtracting(@GeometryBuilder<D> _ negative: @Sendable @escaping () -> D.Geometry) -> D.Geometry {
        Difference(positive: { self }, negative: negative)
    }

    func subtracting(_ negative: (D.Geometry)?...) -> D.Geometry {
        Difference(positive: { self }, negative: { Union(negative) })
    }
}
