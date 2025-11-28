import Foundation

internal struct Separate<D: Dimensionality>: Geometry {
    let body: D.Geometry
    let reader: @Sendable ([D.Geometry]) -> D.Geometry

    public func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let result = try await context.buildResult(for: body, in: environment)
        let partCount = try await context.result(for: .decompose(result.node)).parts.count
        let parts = (0..<partCount).map { SeparatedPart(body: body, index: $0) }
        return try await context.buildResult(for: reader(parts), in: environment)
    }
}

internal struct SeparatedPart<D: Dimensionality>: Geometry {
    let body: D.Geometry
    let index: Int

    public func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        try await context.buildResult(for: body, in: environment).modifyingNode {
            .select(.decompose($0), index: index)
        }
    }
}

public extension Geometry {
    /// Splits the geometry into its disconnected components and passes them to a reader closure.
    ///
    /// This method identifies and extracts all topologically disconnected parts of the geometry,
    /// such as individual shells or pieces that do not touch each other. The resulting components
    /// are passed to a closure, allowing you to process, rearrange, or visualize them as desired.
    ///
    /// - Parameter reader: A closure that takes the array of separated components and returns a new geometry.
    /// - Returns: A new geometry built from the components returned by the `reader` closure.
    ///
    /// ## Example
    /// ```swift
    /// model.separated { components in
    ///     Stack(.x, spacing: 1) {
    ///         for component in components {
    ///             component
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// In this example, each disconnected part of the model is extracted and displayed side-by-side
    /// along the X axis with a spacing of 1 mm.
    func separated(@GeometryBuilder<D> reader: @Sendable @escaping (_ components: [D.Geometry]) -> D.Geometry) -> D.Geometry {
        Separate(body: self, reader: reader)
    }
}
