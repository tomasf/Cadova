import Foundation

internal struct Separate<D: Dimensionality, Output: Dimensionality>: Geometry {
    let source: D.Geometry
    let reader: @Sendable ([D.Geometry]) -> Output.Geometry

    public func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<Output> {
        let result = try await context.buildResult(for: source, in: environment)
        let partCount = try await context.result(for: .decompose(result.node)).parts.count
        // Each component is built from a stand-in for the source rather than the source itself, so
        // decomposing into n components costs one build of the source rather than n + 1.
        let standIn = result.standingIn(for: source, in: environment, context: context)
        let parts = (0..<partCount).map { SeparatedPart(body: standIn, index: $0) }
        return try await context.buildResult(for: reader(parts), in: environment)
    }
}

internal struct SeparatedPart<D: Dimensionality>: Geometry {
    let body: D.Geometry
    let index: Int

    public func _build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> BuildResult<D> {
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
    ///
    func separated <Output: Dimensionality> (
        @GeometryBuilder<Output> reader: @Sendable @escaping (_ components: [D.Geometry]) -> Output.Geometry
    ) -> Output.Geometry {
        Separate(source: self, reader: reader)
    }
}
