import Foundation
import Manifold3D

/// Reads derived values from geometry inside a ``Geometry/evaluating(_:)`` block.
///
/// `GeometryEvaluator` exposes the same kinds of reads offered by the single-purpose reader methods
/// (``Geometry/measuring(_:_:)``, ``Geometry2D/readingOutlines(_:)``, ``Geometry/separated(reader:)``,
/// ``Geometry3D/readingSurfaces(from:in:_:)``, and so on), but as `async` methods on a single
/// evaluator object. This lets one closure perform several reads — across the input geometry or any
/// other geometry in scope — without nesting reader calls.
///
/// You don't construct a `GeometryEvaluator` directly; it is handed to the closure passed to
/// ``Geometry/evaluating(_:)`` or ``Evaluate``:
///
/// ```swift
/// shape.evaluating { g, eval in
///     let bounds   = await eval.bounds(of: g) ?? .zero
///     let outlines = await eval.outlines(of: g.projected())
///     // ...build using both
/// }
/// ```
///
public actor GeometryEvaluator {
    internal let context: EvaluationContext
    internal let environment: EnvironmentValues
    internal private(set) var firstError: (any Error)?

    internal init(context: EvaluationContext, environment: EnvironmentValues) {
        self.context = context
        self.environment = environment
    }

    internal func capture<T>(fallback: T, _ work: () async throws -> T) async -> T {
        guard firstError == nil else { return fallback }
        do {
            return try await work()
        } catch {
            if firstError == nil { firstError = error }
            return fallback
        }
    }
}
