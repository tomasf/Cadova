import Foundation


fileprivate struct Measure<Input: Dimensionality, D: Dimensionality>: Geometry {
    let target: [Input.Geometry]
    let scope: MeasurementScope
    let builder: @Sendable ([Measurements<Input>]) -> D.Geometry

    func build(in environment: EnvironmentValues, context: EvaluationContext) async throws -> D.BuildResult {
        let buildResults = try await context.buildResults(for: target, in: environment)
        let measurements = try await buildResults.asyncMap {
            try await Measurements(buildResult: $0, scope: scope, context: context)
        }
        let generatedGeometry = builder(measurements)
        return try await context.buildResult(for: generatedGeometry, in: environment)
    }
}

public extension Geometry {
    /// Applies custom modifications to a geometry based on its measured properties.
    ///
    /// This method evaluates the geometry and passes its measurements (such as area/volume and
    /// bounding boxes) to a closure. The closure can then return a modified geometry based on
    /// these measurements.
    ///
    /// The ``MeasurementScope`` controls which parts are included when computing the
    /// measurements. Depending on the scope, measurements may include the main geometry only,
    /// the main geometry plus solid parts, or all parts (solid/context/visual). Parts are
    /// currently 3D-only; when measuring 2D geometry, the scope has no effect.
    ///
    /// - Parameters:
    ///   - scope: Which parts to include when computing measurements. Use `.mainPart` to measure
    ///            only the main geometry, `.solidParts` (default) to include solid/printable parts,
    ///            or `.allParts` to include every part (solid, context, and visual).
    ///   - builder: A closure that accepts the current geometry and its measurements, and returns
    ///              a modified geometry.
    /// - Returns: A new geometry resulting from the builder’s modifications.
    ///
    func measuring<Output: Dimensionality>(
        _ scope: MeasurementScope = .solidParts,
        @GeometryBuilder<Output> _ builder: @Sendable @escaping (D.Geometry, D.Measurements) -> Output.Geometry
    ) -> Output.Geometry {
        Measure(target: [self], scope: scope) {
            builder(self, $0[0])
        }
    }

    /// Measures the geometry and provides a bounding box to a closure, if available.
    ///
    /// This is a convenience method for cases where you only need the bounding box of a geometry
    /// and want to avoid dealing with optionals.
    ///
    /// The returned bounding box is computed according to the provided ``MeasurementScope``.
    /// Depending on the scope, the box may include the main geometry only, the main geometry plus
    /// solid parts, or all parts (solid/context/visual). Parts are currently 3D-only; when measuring
    /// 2D geometry, the scope has no effect.
    ///
    /// If the geometry has a bounding box (i.e., it’s not empty), it is passed to the closure along
    /// with the geometry itself. If the geometry is empty and has no bounds, the `empty` closure is
    /// evaluated to provide a fallback geometry instead.
    ///
    /// - Parameters:
    ///   - scope: Which parts to include when computing the bounding box. Use `.mainPart` to consider
    ///            only the main geometry, `.solidParts` (default) to include solid/printable parts, or
    ///            `.allParts` to include every part (solid, context, and visual).
    ///   - builder: A closure that receives the geometry and its bounding box, and returns a new geometry.
    ///   - empty: A closure that provides fallback geometry when the original geometry is empty. Defaults to `Empty()`.
    /// - Returns: A modified geometry based on the bounding box, or the result of `empty` if no bounds exist.
    ///
    func measuringBounds<Output: Dimensionality>(
        scope: MeasurementScope = .solidParts,
        @GeometryBuilder<Output> _ builder: @Sendable @escaping (D.Geometry, D.BoundingBox) -> Output.Geometry,
        @GeometryBuilder<Output> empty emptyBuilder: @Sendable @escaping () -> Output.Geometry = { Empty() },
    ) -> Output.Geometry {
        measuring(scope) { geometry, measurements in
            if let box = measurements.boundingBox {
                builder(geometry, box)
            } else {
                geometry.replaced { _ in emptyBuilder() }
            }
        }
    }

    /// Replaces the geometry with an alternative if it is empty.
    ///
    /// This method checks whether the geometry is empty using its computed measurements.
    /// If the geometry is empty, the provided closure is evaluated and returned instead.
    /// Otherwise, the original geometry is returned unchanged.
    ///
    /// This is useful for providing fallback geometry in cases where earlier steps
    /// may produce an empty result.
    ///
    /// - Parameter replacement: A closure that returns an alternative geometry to use if the original is empty.
    /// - Returns: Either the original geometry or the result of the replacement closure.
    func ifEmpty(@GeometryBuilder<D> _ replacement: @Sendable @escaping () -> D.Geometry) -> D.Geometry {
        measuring { input, measurements in
            measurements.isEmpty ? input.replaced { _ in replacement() } : input
        }
    }
}

/// Measures the bounding boxes of multiple geometries and forwards the results to a reader closure.
///
/// This utility evaluates each geometry in `targets` using the specified `scope`, computes an
/// optional bounding box for each (some geometries may be empty and therefore have no bounds),
/// and passes the array of results to `reader`. The `reader` closure can then return any geometry
/// based on those measurements.
///
/// - Parameters:
///   - targets: An array of geometries to measure. Each element is evaluated and measured independently,
///              producing a corresponding optional bounding box.
///   - scope: The measurement scope that determines which parts are included when computing bounding boxes.
///            Use `.mainPart` to measure only the main geometry, `.solidParts` (default) to include solid/printable
///            parts, or `.allParts` to include every part (solid, context, and visual). Note that parts are currently
///            3D-only; when measuring 2D geometry, the scope has no effect.
///   - reader: A closure that receives an array of optional bounding boxes (one per target, in the same order).
///             Each element is `nil` if the corresponding geometry is empty or has no bounds. The closure should
///             return a geometry derived from these measurements.
/// - Returns: The geometry produced by the `reader` closure, typically constructed using the provided bounding boxes.
///
public func measureBounds<Input: Dimensionality, D: Dimensionality>(
    of targets: [Input.Geometry],
    scope: MeasurementScope = .solidParts,
    reader: @Sendable @escaping ([BoundingBox<Input>?]) -> D.Geometry
) -> D.Geometry {
    Measure(target: targets, scope: scope) { measurements in
        reader(measurements.map(\.boundingBox))
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

internal extension MeasurementScope {
    func includedConcretes<D: Dimensionality>(
        for buildResult: BuildResult<D>,
        in context: EvaluationContext
    ) async throws -> [D.Concrete] {
        let main = try await context.result(for: buildResult.node)
        guard let main3D = main as? EvaluationResult<D3> else {
            // Parts are currently always 3D. Because we can't mix dimensionalities for measurement
            // purposes, we can't use parts in 2D measurements at all.
            return [main.concrete]
        }

        let allParts = buildResult.elements[PartCatalog.self].mergedOutputs
        let additionalParts: [D3.BuildResult]

        switch self {
        case .mainPart: additionalParts = []
        case .solidParts: additionalParts = allParts.filter { $0.key.semantic == .solid }.map(\.value)
        case .allParts: additionalParts = Array(allParts.values)
        }

        let partResults = try await additionalParts.asyncMap { try await context.result(for: $0.node) }

        let foo = [main3D.concrete] + partResults.map(\.concrete)
        return foo as! [D.Concrete]
    }
}
