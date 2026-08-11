import Foundation

public extension GeometryEvaluator {
    /// Returns the topologically disconnected components of `geometry` as separate geometries.
    ///
    /// Each component is an independent piece — a shell or island that doesn't touch any of the
    /// others. Components are returned in an arbitrary but stable order. This is the evaluator
    /// equivalent of ``Geometry/separated(reader:)``; the elements behave like ordinary geometry
    /// and can be combined, transformed, or returned individually.
    ///
    /// ```swift
    /// model.evaluating { g, eval in
    ///     let parts = await eval.components(of: g)
    ///     Stack(.x, spacing: 1) {
    ///         for part in parts { part }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter geometry: The geometry to decompose.
    /// - Returns: The disconnected components. Empty if `geometry` is empty.
    ///
    func components<D: Dimensionality>(of geometry: D.Geometry) async -> [D.Geometry] {
        await capture(fallback: []) {
            let buildResult = try await context.buildResult(for: geometry, in: environment)
            let partCount = try await context.result(for: .decompose(buildResult.node)).parts.count
            return (0..<partCount).map { SeparatedPart(body: geometry, index: $0) }
        }
    }

    /// Extracts the outlines of a 2D geometry as closed Bézier paths.
    ///
    /// The geometry's concrete shape is sampled and its polygonal outlines are wrapped as
    /// ``BezierPath2D`` values made of straight segments. This is the evaluator equivalent of
    /// ``Geometry/readingOutlines(_:)``.
    ///
    /// - Parameter geometry: The 2D geometry whose outlines should be read.
    /// - Returns: One closed Bézier path per outline contour.
    ///
    func outlines(of geometry: any Geometry2D) async -> [BezierPath2D] {
        await capture(fallback: []) {
            let buildResult = try await context.buildResult(for: geometry, in: environment)
            let evalResult = try await context.result(for: buildResult.node)
            return evalResult.concrete.polygonList().polygons.map {
                BezierPath2D(linesBetween: $0.vertices).closed()
            }
        }
    }
}
