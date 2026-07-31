import Foundation

public extension GeometryEvaluator {
    /// Returns the ``ResultElement`` of the given type attached to `geometry`'s build result.
    ///
    /// Result elements are typed pieces of metadata that travel alongside geometry through the
    /// build pipeline — used for things like part catalogs, anchor records, or custom statistics.
    /// This is the evaluator equivalent of ``Geometry/readingResult(_:generator:)``.
    ///
    /// If `geometry` carries no element of type `E`, a default-constructed `E()` is returned —
    /// matching the semantics of ``Geometry/readingResult(_:generator:)``. The default value is also
    /// what you get if an earlier read in this block failed.
    ///
    /// - Parameters:
    ///   - type: The element type to read.
    ///   - geometry: The geometry to read from.
    /// - Returns: The attached element, or a default-constructed value if none is present.
    ///
    func result<E: ResultElement, D: Dimensionality>(
        _ type: E.Type,
        of geometry: D.Geometry
    ) async -> E {
        await capture(fallback: E()) {
            let buildResult = try await context.buildResult(for: geometry, in: environment)
            return buildResult.elements[type]
        }
    }
}
