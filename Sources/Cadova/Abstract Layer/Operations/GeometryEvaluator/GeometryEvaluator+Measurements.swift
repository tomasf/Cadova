import Foundation

public extension GeometryEvaluator {
    /// Returns the measurements of `geometry` — bounding box, area/volume, vertex counts, and so on.
    ///
    /// This is the evaluator equivalent of ``Geometry/measuring(_:_:)``. The ``MeasurementScope``
    /// controls which parts are included when computing the measurements: only the main geometry,
    /// the main geometry plus solid parts, or every part (solid, context, and visual).
    ///
    /// - Parameters:
    ///   - geometry: The geometry to measure.
    ///   - scope: Which parts to include. Defaults to `.solidParts`.
    /// - Returns: A ``Measurements`` value.
    ///
    func measurements<D: Dimensionality>(
        of geometry: D.Geometry,
        scope: MeasurementScope = .solidParts
    ) async -> Measurements<D> {
        await capture(fallback: Measurements()) {
            let buildResult = try await context.buildResult(for: geometry, in: environment)
            return try await Measurements(buildResult: buildResult, scope: scope, context: context)
        }
    }

    /// Returns the bounding box of `geometry`, or `nil` if it is empty.
    ///
    /// Convenience over ``measurements(of:scope:)`` when only the bounding box is needed. For empty
    /// geometries the result is `nil.
    ///
    /// - Parameters:
    ///   - geometry: The geometry to measure.
    ///   - scope: Which parts to include when computing the bounding box. Defaults to `.solidParts`.
    /// - Returns: The axis-aligned bounding box, or `nil` if `geometry` is empty.
    ///
    func bounds<D: Dimensionality>(
        of geometry: D.Geometry,
        scope: MeasurementScope = .solidParts
    ) async -> BoundingBox<D>? {
        await measurements(of: geometry, scope: scope).boundingBox
    }

    /// Reports whether `geometry` is empty.
    ///
    /// Equivalent to checking ``Measurements/isEmpty`` on a `.solidParts`-scoped measurement, but
    /// shorter at the call site. Useful for skipping fallback geometry when something earlier in
    /// the pipeline may have produced nothing.
    ///
    /// - Parameter geometry: The geometry to test.
    /// - Returns: `true` if `geometry` has no content.
    ///
    func isEmpty<D: Dimensionality>(_ geometry: D.Geometry) async -> Bool {
        await measurements(of: geometry, scope: .solidParts).isEmpty
    }
}
