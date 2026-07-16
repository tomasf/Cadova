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
/// ``Geometry/evaluating(_:)``:
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
    private let context: EvaluationContext
    private let environment: EnvironmentValues
    internal private(set) var firstError: (any Error)?

    internal init(context: EvaluationContext, environment: EnvironmentValues) {
        self.context = context
        self.environment = environment
    }

    private func capture<T>(fallback: T, _ work: () async throws -> T) async -> T {
        guard firstError == nil else { return fallback }
        do {
            return try await work()
        } catch {
            if firstError == nil { firstError = error }
            return fallback
        }
    }

    // MARK: - Measurements

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
    public func measurements<D: Dimensionality>(
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
    public func bounds<D: Dimensionality>(
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
    public func isEmpty<D: Dimensionality>(_ geometry: D.Geometry) async -> Bool {
        await measurements(of: geometry, scope: .solidParts).isEmpty
    }

    // MARK: - Topology / structure

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
    public func components<D: Dimensionality>(of geometry: D.Geometry) async -> [D.Geometry] {
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
    /// ``Geometry2D/readingOutlines(_:)``.
    ///
    /// - Parameter geometry: The 2D geometry whose outlines should be read.
    /// - Returns: One closed Bézier path per outline contour.
    ///
    public func outlines(of geometry: any Geometry2D) async -> [BezierPath2D] {
        await capture(fallback: []) {
            let buildResult = try await context.buildResult(for: geometry, in: environment)
            let evalResult = try await context.result(for: buildResult.node)
            return evalResult.concrete.polygonList().polygons.map {
                BezierPath2D(linesBetween: $0.vertices).closed()
            }
        }
    }

    // MARK: - Spatial queries

    /// Returns every surface crossing where `segment` enters or exits `geometry`.
    ///
    /// Each crossing carries its position, surface normal, and parameter along the segment. Crossings
    /// are sorted by ascending ``SurfaceCrossing/distance`` and lie within `0...segment.length`. This
    /// is the evaluator equivalent of ``Geometry3D/readingSurfaces(along:_:)``.
    ///
    /// - Parameters:
    ///   - geometry: The 3D geometry to query.
    ///   - segment: The segment along which to look for crossings.
    /// - Returns: All crossings within the segment, sorted by distance.
    ///
    public func surfaces(of geometry: any Geometry3D, along segment: LineSegment3D) async -> [SurfaceCrossing] {
        await capture(fallback: []) {
            let buildResult = try await context.buildResult(for: geometry, in: environment)
            let evalResult = try await context.result(for: buildResult.node)
            let hits = evalResult.concrete.rayCast(from: segment.start, to: segment.end)
            return hits.map {
                SurfaceCrossing(hit: $0, origin: segment.start, direction: segment.direction)
            }
        }
    }

    /// Casts a ray forward from `origin` in `direction` and returns every surface crossing on `geometry`.
    ///
    /// The ray extends forward only — surfaces behind `origin` are never reported. Internally the ray
    /// is clipped to a segment long enough to span the geometry's bounding box, so all forward
    /// crossings are returned regardless of how far away the geometry is. This is the evaluator
    /// equivalent of ``Geometry3D/readingSurfaces(from:in:_:)``.
    ///
    /// - Parameters:
    ///   - geometry: The 3D geometry to query.
    ///   - origin: The starting point of the ray.
    ///   - direction: The direction the ray extends.
    /// - Returns: All forward crossings on `geometry`, sorted by distance. Empty if the geometry is
    ///            empty or the ray misses entirely.
    ///
    public func surfaces(of geometry: any Geometry3D, from origin: Vector3D, in direction: Direction3D) async -> [SurfaceCrossing] {
        guard let bounds = await bounds(of: geometry) else { return [] }
        return await surfaces(of: geometry, along: bounds.coveringSegment(from: origin, in: direction))
    }

    /// Returns the first surface crossing on `geometry` within `segment`, or `nil` if there are none.
    ///
    /// Convenience over ``surfaces(of:along:)`` when only the nearest hit is interesting — for
    /// example, finding where a peg lands on a curved surface.
    ///
    /// - Parameters:
    ///   - geometry: The 3D geometry to query.
    ///   - segment: The segment along which to look for crossings.
    /// - Returns: The nearest crossing within `segment`, or `nil` if none.
    ///
    public func firstSurface(of geometry: any Geometry3D, along segment: LineSegment3D) async -> SurfaceCrossing? {
        await surfaces(of: geometry, along: segment).first
    }

    /// Returns the first surface crossing along the ray from `origin` in `direction`, or `nil` if the
    /// ray hits nothing.
    ///
    /// Convenience over ``surfaces(of:from:in:)``. The ray extends forward only.
    ///
    /// - Parameters:
    ///   - geometry: The 3D geometry to query.
    ///   - origin: The starting point of the ray.
    ///   - direction: The direction the ray extends.
    /// - Returns: The nearest forward crossing, or `nil` if the ray misses.
    ///
    public func firstSurface(of geometry: any Geometry3D, from origin: Vector3D, in direction: Direction3D) async -> SurfaceCrossing? {
        await surfaces(of: geometry, from: origin, in: direction).first
    }

    // MARK: - Parts

    /// Returns all parts of `geometry` whose semantic matches `type`, keyed by ``Part``.
    ///
    /// The original geometry is not modified — parts are read in place. This is the evaluator
    /// equivalent of ``Geometry/readingParts(ofType:reader:)``. Use it to inspect or selectively
    /// reuse parts of a model (for example, to overlay all `.visual` parts or to lay out each
    /// `.solid` part for inspection) without detaching them.
    ///
    /// - Parameters:
    ///   - geometry: The geometry to inspect.
    ///   - type: The semantic of parts to read. Defaults to `.solid`.
    /// - Returns: A dictionary mapping each matching part to its combined geometry.
    ///
    public func parts<D: Dimensionality>(of geometry: D.Geometry, ofType type: PartSemantic = .solid) async -> [Part: D3.Geometry] {
        await capture(fallback: [:]) {
            let buildResult = try await context.buildResult(for: geometry, in: environment)
            return buildResult.elements[PartCatalog.self].asGeometry(filteredBy: type)
        }
    }

    /// Returns the geometry of a single named part of `geometry`, or `nil` if the part is not present.
    ///
    /// The original geometry is not modified. This is the evaluator equivalent of
    /// ``Geometry/readingPart(_:reader:)``.
    ///
    /// - Parameters:
    ///   - part: The part to read.
    ///   - geometry: The geometry to inspect.
    /// - Returns: The combined geometry of the named part, or `nil` if it is not present.
    ///
    public func part<D: Dimensionality>(_ part: Part, of geometry: D.Geometry) async -> D3.Geometry? {
        await capture(fallback: nil) {
            let buildResult = try await context.buildResult(for: geometry, in: environment)
            return buildResult.elements[PartCatalog.self].asGeometry(matching: [part]).values.first
        }
    }

    // MARK: - Result elements

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
    public func result<E: ResultElement, D: Dimensionality>(
        _ type: E.Type,
        of geometry: D.Geometry
    ) async -> E {
        await capture(fallback: E()) {
            let buildResult = try await context.buildResult(for: geometry, in: environment)
            return buildResult.elements[type]
        }
    }
}
