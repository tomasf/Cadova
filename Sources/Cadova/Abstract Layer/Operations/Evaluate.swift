import Foundation

/// A geometry type that reads derived values from other geometry using a ``GeometryEvaluator``, then
/// builds new geometry from the results.
///
/// Use `Evaluate` when you need to read from geometry that isn't the receiver of a chained call — for
/// example, geometry captured from an outer scope, or several unrelated geometries at once. If you're
/// evaluating the geometry you're already chaining off of, ``Geometry/evaluating(_:)`` is more concise.
///
/// ```swift
/// Evaluate { eval in
///     let bounds   = await eval.bounds(of: someShape) ?? .zero
///     let outlines = await eval.outlines(of: otherShape.projected())
///     someShape.adding {
///         for path in outlines {
///             // place a marker on each outline using the bounds
///         }
///     }
/// }
/// ```
///
public struct Evaluate<D: Dimensionality>: Geometry {
    let action: @Sendable (GeometryEvaluator) async -> D.Geometry

    /// Creates a geometry that reads derived values from other geometry, then builds new geometry from
    /// the results.
    /// - Parameter action: An asynchronous closure that receives an evaluator and returns new geometry
    ///   built from the values read through it.
    public init(
        @GeometryBuilder<D> _ action: @Sendable @escaping (GeometryEvaluator) async -> D.Geometry
    ) {
        self.action = action
    }

    public func _build(in environment: EnvironmentValues, context: _EvaluationContext) async throws -> _BuildResult<D> {
        let evaluator = GeometryEvaluator(context: context, environment: environment)
        let produced = await action(evaluator)
        if let error = await evaluator.firstError {
            throw error
        }
        return try await context.buildResult(for: produced, in: environment)
    }
}

public extension Geometry {
    /// Performs several geometry reads inside one closure, then builds new geometry from the results.
    ///
    /// Single-purpose readers like ``measuring(_:_:)``, ``Geometry/readingOutlines(_:)``, and ``separated(reader:)``
    /// each pass one derived value to a synchronous closure. When you need several derived values at
    /// once — bounds *and* outlines *and* component count — chaining the single-purpose readers forces
    /// a pyramid of nested closures. `evaluating` collapses that into one async closure that receives a
    /// ``GeometryEvaluator``. Each read is a call on the evaluator, freely interleaved with normal Swift
    /// code, loops, and `let` bindings.
    ///
    /// The evaluator runs in the same evaluation context and environment that the surrounding pipeline
    /// uses, so reads share the same cache. Reading the same geometry several times inside one
    /// `evaluating` block costs no more than reading it once. The evaluator can read any geometry in
    /// scope — the closure's input, geometry captured from outer scope, or geometry built on the fly.
    ///
    /// ```swift
    /// shape.evaluating { g, eval in
    ///     let bounds   = await eval.bounds(of: g) ?? .zero
    ///     let outlines = await eval.outlines(of: g.projected())
    ///     g.adding {
    ///         for path in outlines {
    ///             // place a marker on each outline using the bounds
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// For a single read, the existing single-purpose readers (``measuring(_:_:)``,
    /// ``Geometry/readingOutlines(_:)``, ``separated(reader:)``, etc.) remain the simpler choice. Reach for
    /// `evaluating` when there are two or more reads, or when reads need to be driven by a loop.
    ///
    /// - Parameter action: An asynchronous closure that receives this geometry and an evaluator, and
    ///                     returns new geometry built from the values read through the evaluator.
    /// - Returns: The geometry produced by `action`.
    ///
    func evaluating<Output: Dimensionality>(
        @GeometryBuilder<Output> _ action: @Sendable @escaping (D.Geometry, GeometryEvaluator) async -> Output.Geometry
    ) -> Output.Geometry {
        Evaluate { eval in
            await action(self, eval)
        }
    }
}
