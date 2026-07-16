import Foundation

/// A composable set of criteria for selecting which edges of a model to act on.
///
/// Every modifier is also available as a static starting point, so a query can begin directly
/// with whichever criterion matters to you:
///
/// ```swift
/// .along(.z)                            // vertical edges only
/// .within(z: 4.9...).convex             // convex edges near the top
/// .withSharpness(80°...100°).convex     // near-square convex edges only
/// ```
///
/// Use `.all` when you don't need any filtering beyond the default sharpness (30° deviation
/// from flat — this is also the minimum used when starting from any other modifier). Edges
/// continue through gentle direction changes but split at corners turning more than 45°;
/// adjust with `withMaxTurn(_:)`.
///
/// Pass the query to `readingEdges(matching:)` or `shapingEdges(_:matching:)`.
///
public struct EdgeQuery: Sendable, Hashable, Codable {
    /// Minimum angular deviation from flat (180°) required for an edge to be considered sharp.
    let minimumSharpness: Angle

    /// Maximum angular deviation from flat (180°) allowed, if narrowing away from very sharp
    /// (knife-edge) features. `nil` means unbounded.
    let maximumSharpness: Angle?

    /// The largest change of direction an edge can make at a vertex and still continue as the
    /// same edge. Turns beyond this split the chain into separate edges.
    let maximumTurnAngle: Angle

    let directionalConstraint: DirectionalConstraint?
    let spatialConstraints: [SpatialConstraint]
    let topologyConstraint: TopologyConstraint?
    let convexityConstraint: ConvexityConstraint?
    let lengthConstraint: LengthConstraint?
    let maskConstraints: [MaskConstraint]

    internal init(
        minimumSharpness: Angle = 30°,
        maximumSharpness: Angle? = nil,
        maximumTurnAngle: Angle = 45°,
        directionalConstraint: DirectionalConstraint? = nil,
        spatialConstraints: [SpatialConstraint] = [],
        topologyConstraint: TopologyConstraint? = nil,
        convexityConstraint: ConvexityConstraint? = nil,
        lengthConstraint: LengthConstraint? = nil,
        maskConstraints: [MaskConstraint] = []
    ) {
        self.minimumSharpness = minimumSharpness
        self.maximumSharpness = maximumSharpness
        self.maximumTurnAngle = maximumTurnAngle
        self.directionalConstraint = directionalConstraint
        self.spatialConstraints = spatialConstraints
        self.topologyConstraint = topologyConstraint
        self.convexityConstraint = convexityConstraint
        self.lengthConstraint = lengthConstraint
        self.maskConstraints = maskConstraints
    }

    /// Selects all edges, using the default sharpness (30° deviation from flat).
    public static let all = EdgeQuery()
}

// MARK: - Modifiers

public extension EdgeQuery {
    private func adding(_ constraint: SpatialConstraint) -> EdgeQuery {
        EdgeQuery(
            minimumSharpness: minimumSharpness,
            maximumSharpness: maximumSharpness,
            maximumTurnAngle: maximumTurnAngle,
            directionalConstraint: directionalConstraint,
            spatialConstraints: spatialConstraints + [constraint],
            topologyConstraint: topologyConstraint,
            convexityConstraint: convexityConstraint,
            lengthConstraint: lengthConstraint,
            maskConstraints: maskConstraints
        )
    }

    private func adding(_ constraint: MaskConstraint) -> EdgeQuery {
        EdgeQuery(
            minimumSharpness: minimumSharpness,
            maximumSharpness: maximumSharpness,
            maximumTurnAngle: maximumTurnAngle,
            directionalConstraint: directionalConstraint,
            spatialConstraints: spatialConstraints,
            topologyConstraint: topologyConstraint,
            convexityConstraint: convexityConstraint,
            lengthConstraint: lengthConstraint,
            maskConstraints: maskConstraints + [constraint]
        )
    }

    private func with(directional: DirectionalConstraint) -> EdgeQuery {
        EdgeQuery(
            minimumSharpness: minimumSharpness,
            maximumSharpness: maximumSharpness,
            maximumTurnAngle: maximumTurnAngle,
            directionalConstraint: directional,
            spatialConstraints: spatialConstraints,
            topologyConstraint: topologyConstraint,
            convexityConstraint: convexityConstraint,
            lengthConstraint: lengthConstraint,
            maskConstraints: maskConstraints
        )
    }

    private func with(topology: TopologyConstraint) -> EdgeQuery {
        EdgeQuery(
            minimumSharpness: minimumSharpness,
            maximumSharpness: maximumSharpness,
            maximumTurnAngle: maximumTurnAngle,
            directionalConstraint: directionalConstraint,
            spatialConstraints: spatialConstraints,
            topologyConstraint: topology,
            convexityConstraint: convexityConstraint,
            lengthConstraint: lengthConstraint,
            maskConstraints: maskConstraints
        )
    }

    private func with(convexity: ConvexityConstraint) -> EdgeQuery {
        EdgeQuery(
            minimumSharpness: minimumSharpness,
            maximumSharpness: maximumSharpness,
            maximumTurnAngle: maximumTurnAngle,
            directionalConstraint: directionalConstraint,
            spatialConstraints: spatialConstraints,
            topologyConstraint: topologyConstraint,
            convexityConstraint: convexity,
            lengthConstraint: lengthConstraint,
            maskConstraints: maskConstraints
        )
    }

    private func with(length: LengthConstraint) -> EdgeQuery {
        EdgeQuery(
            minimumSharpness: minimumSharpness,
            maximumSharpness: maximumSharpness,
            maximumTurnAngle: maximumTurnAngle,
            directionalConstraint: directionalConstraint,
            spatialConstraints: spatialConstraints,
            topologyConstraint: topologyConstraint,
            convexityConstraint: convexityConstraint,
            lengthConstraint: length,
            maskConstraints: maskConstraints
        )
    }

    /// Extracts the lower/upper bounds of a range expression over `Angle`, treating a missing
    /// lower bound as "use the default minimum" and a missing upper bound as "unbounded".
    private static func sharpnessBounds(of range: some RangeExpression<Angle>) -> (lower: Angle?, upper: Angle?) {
        switch range {
        case let range as ClosedRange<Angle>:         (range.lowerBound, range.upperBound)
        case let range as Range<Angle>:               (range.lowerBound, range.upperBound)
        case let range as PartialRangeFrom<Angle>:    (range.lowerBound, nil)
        case let range as PartialRangeThrough<Angle>: (nil, range.upperBound)
        case let range as PartialRangeUpTo<Angle>:    (nil, range.upperBound)
        default:                                      (nil, nil)
        }
    }

    /// Returns a query that only accepts edges whose sharpness (deviation from flat,
    /// `180° - dihedralAngle`) falls within `range`.
    ///
    /// Since sharpness is unsigned, a given band matches both a convex and a concave edge at
    /// the mirrored angle (e.g. `80°...100°` matches both ~90° and ~270° dihedral angles) —
    /// combine with `.convex`/`.concave` to select just one side. An open-ended lower bound
    /// (e.g. `...60°`) keeps the current minimum; an open-ended upper bound removes any maximum.
    ///
    /// Unlike every other modifier here, this affects which mesh discontinuities are recognized
    /// as edges at all, not just which of the already-found edges pass through: an edge whose
    /// sharpness falls outside the band is invisible to chain-building, so an excluded edge at a
    /// junction won't split a chain the way an excluded direction, position, or convexity would.
    ///
    /// ```swift
    /// .withSharpness(80°...100°)   // near-square edges, convex or concave
    /// .withSharpness(60°...)       // sharper than 60°, no maximum
    /// ```
    ///
    func withSharpness(_ range: some RangeExpression<Angle> & Sendable) -> EdgeQuery {
        let (lower, upper) = Self.sharpnessBounds(of: range)
        precondition(lower == nil || upper == nil || upper! > lower!, "the range's upper bound must exceed its lower bound")
        return EdgeQuery(
            minimumSharpness: lower ?? minimumSharpness,
            maximumSharpness: upper,
            maximumTurnAngle: maximumTurnAngle,
            directionalConstraint: directionalConstraint,
            spatialConstraints: spatialConstraints,
            topologyConstraint: topologyConstraint,
            convexityConstraint: convexityConstraint,
            lengthConstraint: lengthConstraint,
            maskConstraints: maskConstraints
        )
    }

    /// Returns a query that only accepts edges whose sharpness (deviation from flat) is within
    /// `tolerance` of `angle`.
    ///
    /// - Parameters:
    ///   - angle: The target sharpness.
    ///   - tolerance: How far from `angle` an edge's sharpness can be. Default 1°.
    func withSharpness(_ angle: Angle, tolerance: Angle = 1°) -> EdgeQuery {
        withSharpness((angle - tolerance)...(angle + tolerance))
    }

    /// Returns a query allowing edges to turn up to `angle` at a vertex while still continuing
    /// as the same edge.
    ///
    /// The default is 45°: corners sharper than that split an edge into separate ones, while
    /// gentler direction changes — like the segments of a reasonably segmented curve — flow
    /// through as one continuous edge. Raise the limit to treat sharp corners as continuations
    /// (e.g. the full rim of a shape with rounded vertical edges as a single closed loop), or
    /// lower it to break edges apart at even slight bends.
    ///
    /// Like `withSharpness(_:)`, this affects how edges are assembled during extraction rather
    /// than filtering the results afterwards. Note that it only applies where an edge could
    /// continue in the first place: vertices where three or more edges meet are always corners.
    ///
    /// ```swift
    /// .withMaxTurn(90°)   // continue through right-angle corners
    /// ```
    ///
    func withMaxTurn(_ angle: Angle) -> EdgeQuery {
        EdgeQuery(
            minimumSharpness: minimumSharpness,
            maximumSharpness: maximumSharpness,
            maximumTurnAngle: angle,
            directionalConstraint: directionalConstraint,
            spatialConstraints: spatialConstraints,
            topologyConstraint: topologyConstraint,
            convexityConstraint: convexityConstraint,
            lengthConstraint: lengthConstraint,
            maskConstraints: maskConstraints
        )
    }

    /// Returns a query that only accepts edges whose total length falls within `range`.
    ///
    /// Unlike `withSharpness(_:)`/`withMaxTurn(_:)`, this is a pure post-filter: it doesn't
    /// affect how edges are assembled from the mesh, only which of the already-built edges
    /// pass through. Useful for excluding short noise edges left over from tessellation or
    /// nearby boolean seams, or for isolating a specific edge you know the length of.
    ///
    /// ```swift
    /// .withLength(5...)     // ignore anything shorter than 5 units
    /// ```
    ///
    /// - Parameter range: The range of acceptable total edge lengths.
    func withLength(_ range: some WithinRange) -> EdgeQuery {
        with(length: LengthConstraint(bound: RangeBound(range)))
    }

    /// Returns a query that only accepts edges running predominantly along `axis`.
    ///
    /// - Parameters:
    ///   - axis: The axis to check alignment against.
    ///   - tolerance: How far from perfectly aligned a segment can be. Default 15°.
    func along(_ axis: Axis3D, tolerance: Angle = 15°) -> EdgeQuery {
        parallel(to: Direction3D(axis, .positive), tolerance: tolerance)
    }

    /// Returns a query that only accepts edges lying along the given line.
    ///
    /// Unlike `along(_:tolerance:)` with an axis — which only constrains where edges point —
    /// a line is positioned in space, so this selects edges that actually run on it: every
    /// vertex must fall within `tolerance` of the line. Use it to pick out one specific edge
    /// you know geometrically, at any orientation:
    ///
    /// ```swift
    /// .along(line: Line3D(from: [0, 0, 10], to: [10, 4, 13]))
    /// ```
    ///
    /// To match edges pointing like a line regardless of where they are, use
    /// `parallel(to:tolerance:)` instead.
    ///
    /// - Parameters:
    ///   - line: The line to match against.
    ///   - tolerance: How far from the line a vertex may be. Default 0.01.
    func along(line: Line3D, tolerance: Double = 0.01) -> EdgeQuery {
        adding(.onLine(line, tolerance: tolerance))
    }

    /// Returns a query that only accepts edges running predominantly parallel to `direction`,
    /// anywhere in space. Either orientation along the direction counts.
    ///
    /// - Parameters:
    ///   - direction: The direction to check alignment against.
    ///   - tolerance: How far from perfectly parallel a segment can be. Default 15°.
    func parallel(to direction: Direction3D, tolerance: Angle = 15°) -> EdgeQuery {
        with(directional: .parallel(direction, tolerance: tolerance))
    }

    /// Returns a query that only accepts edges running predominantly parallel to `line`,
    /// anywhere in space — only the line's direction matters, not its position. To select
    /// edges lying on the line itself, use `along(line:tolerance:)`.
    ///
    /// - Parameters:
    ///   - line: The line whose direction to check alignment against.
    ///   - tolerance: How far from perfectly parallel a segment can be. Default 15°.
    func parallel(to line: Line3D, tolerance: Angle = 15°) -> EdgeQuery {
        parallel(to: line.direction, tolerance: tolerance)
    }

    /// Returns a query that only accepts edges running predominantly perpendicular to `axis`.
    ///
    /// - Parameters:
    ///   - axis: The axis to check perpendicularity against.
    ///   - tolerance: How far from perfectly perpendicular a segment can be. Default 15°.
    func perpendicular(to axis: Axis3D, tolerance: Angle = 15°) -> EdgeQuery {
        perpendicular(to: Direction3D(axis, .positive), tolerance: tolerance)
    }

    /// Returns a query that only accepts edges running predominantly perpendicular
    /// to `direction`.
    ///
    /// - Parameters:
    ///   - direction: The direction to check perpendicularity against.
    ///   - tolerance: How far from perfectly perpendicular a segment can be. Default 15°.
    func perpendicular(to direction: Direction3D, tolerance: Angle = 15°) -> EdgeQuery {
        with(directional: .perpendicular(to: direction, tolerance: tolerance))
    }

    /// Returns a query that only accepts edges running predominantly perpendicular to
    /// `line` — only the line's direction matters, not its position.
    ///
    /// - Parameters:
    ///   - line: The line whose direction to check perpendicularity against.
    ///   - tolerance: How far from perfectly perpendicular a segment can be. Default 15°.
    func perpendicular(line: Line3D, tolerance: Angle = 15°) -> EdgeQuery {
        perpendicular(to: line.direction, tolerance: tolerance)
    }

    /// Returns a query that only accepts edges entirely within the given box.
    func within(_ box: BoundingBox3D) -> EdgeQuery {
        adding(.withinBox(box))
    }

    /// Returns a query that only accepts edges whose every vertex falls within `range` along `axis`.
    ///
    /// Accepts any range expression, including open-ended ranges:
    ///
    /// ```swift
    /// .within(.x, 3.0...7.0).within(.z, 4.9...)
    /// ```
    ///
    func within(_ axis: Axis3D, _ range: some WithinRange) -> EdgeQuery {
        adding(.withinAxisRange(axis, RangeBound(range)))
    }

    /// Returns a query that only accepts edges entirely within the given ranges.
    ///
    /// Axes that are `nil` are left unbounded. You can use any `Range` expression, including
    /// open, closed, partial, and infinite ranges:
    ///
    /// ```swift
    /// .within(x: 3.0...7.0, z: 4.9...)
    /// ```
    ///
    /// - Parameters:
    ///   - x: Optional range along the x-axis. If `nil`, edges are unrestricted along this axis.
    ///   - y: Optional range along the y-axis. If `nil`, edges are unrestricted along this axis.
    ///   - z: Optional range along the z-axis. If `nil`, edges are unrestricted along this axis.
    ///
    func within(
        x: (any WithinRange)? = nil,
        y: (any WithinRange)? = nil,
        z: (any WithinRange)? = nil
    ) -> EdgeQuery {
        var query = self
        if let x { query = query.adding(.withinAxisRange(.x, RangeBound(x))) }
        if let y { query = query.adding(.withinAxisRange(.y, RangeBound(y))) }
        if let z { query = query.adding(.withinAxisRange(.z, RangeBound(z))) }
        return query
    }

    /// Returns a query that only accepts edges entirely within the given mask shape.
    ///
    /// The mask is treated as a solid: an edge matches only if every one of its vertices lies
    /// inside the mask's volume. Unlike `within(_:)`/`within(_:_:)`, the mask can be any shape,
    /// not just an axis-aligned box or range — a cylinder, a sphere, or an arbitrary CSG shape.
    /// Combine multiple shapes freely; they're unioned into a single mask.
    ///
    /// ```swift
    /// model.shapingEdges(.fillet(radius: 2), matching: .within {
    ///     Cylinder(radius: 5, height: 20)
    /// })
    /// ```
    ///
    /// The mask is evaluated once per query, and containment is memoized per distinct vertex
    /// position, so it stays cheap even with many candidate edges.
    func within(@GeometryBuilder3D mask: @Sendable @escaping () -> any Geometry3D) -> EdgeQuery {
        adding(MaskConstraint(geometry: mask()))
    }

    /// Returns a query that only accepts edges entirely above the given plane
    /// (on the side its normal points towards).
    func above(_ plane: Plane) -> EdgeQuery {
        adding(.above(plane))
    }

    /// Returns a query that only accepts edges entirely below the given plane
    /// (on the opposite side from its normal).
    func below(_ plane: Plane) -> EdgeQuery {
        adding(.below(plane))
    }

    /// Returns a query that only accepts edges lying on the given plane, on either side —
    /// every vertex must fall within `tolerance` of it. Unlike `above(_:)`/`below(_:)`, which
    /// each accept a whole half-space, this pins edges to the plane itself, generalizing
    /// `along(line:tolerance:)` to a two-dimensional surface instead of a one-dimensional line.
    ///
    /// - Parameters:
    ///   - plane: The plane to match against.
    ///   - tolerance: How far from the plane a vertex may be. Default 0.01.
    func on(_ plane: Plane, tolerance: Double = 0.01) -> EdgeQuery {
        adding(.onPlane(plane, tolerance: tolerance))
    }

    /// Returns a query that only accepts edges lying entirely within `radius` of `point` —
    /// every vertex must be that close. This is a direct distance check, not a geometric mask:
    /// no sphere is built or evaluated, so it's exact (no faceting) and cheap regardless of how
    /// finely a sphere would otherwise need to be segmented. Use `within(mask:)` instead when
    /// the region you need isn't a sphere.
    ///
    /// - Parameters:
    ///   - point: The center point to measure distance from.
    ///   - radius: The maximum allowed distance from `point`.
    func near(_ point: Vector3D, within radius: Double) -> EdgeQuery {
        adding(.nearPoint(point, radius: radius))
    }

    /// A query that only accepts closed (loop) edges.
    var closed: EdgeQuery {
        with(topology: .closed)
    }

    /// A query that only accepts open (non-loop) edges.
    var open: EdgeQuery {
        with(topology: .open)
    }

    /// A query that only accepts convex (outside) edges.
    var convex: EdgeQuery {
        with(convexity: .convex)
    }

    /// A query that only accepts concave (inside corner) edges.
    var concave: EdgeQuery {
        with(convexity: .concave)
    }
}

// MARK: - Static starting points
//
// Mirrors every modifier above as a static factory/var starting from `.all`, so a query can begin
// directly with whichever criterion matters — `.convex` rather than `.all.convex` — without
// requiring an arbitrary named prefix to kick off the chain.

public extension EdgeQuery {
    /// Selects edges whose sharpness falls within `range`. See `withSharpness(_:)`.
    static func withSharpness(_ range: some RangeExpression<Angle> & Sendable) -> EdgeQuery {
        all.withSharpness(range)
    }

    /// Selects edges whose sharpness is within `tolerance` of `angle`. See
    /// ``withSharpness(_:tolerance:)``.
    static func withSharpness(_ angle: Angle, tolerance: Angle = 1°) -> EdgeQuery {
        all.withSharpness(angle, tolerance: tolerance)
    }

    /// Selects edges that may turn up to `angle` at a vertex and still continue as the same
    /// edge. See ``withMaxTurn(_:)``.
    static func withMaxTurn(_ angle: Angle) -> EdgeQuery {
        all.withMaxTurn(angle)
    }

    /// Selects edges whose total length falls within `range`. See ``withLength(_:)``.
    static func withLength(_ range: some WithinRange) -> EdgeQuery {
        all.withLength(range)
    }

    /// Selects edges running predominantly along `axis`. See ``along(_:tolerance:)``.
    static func along(_ axis: Axis3D, tolerance: Angle = 15°) -> EdgeQuery {
        all.along(axis, tolerance: tolerance)
    }

    /// Selects edges lying along the given line. See ``along(line:tolerance:)``.
    static func along(line: Line3D, tolerance: Double = 0.01) -> EdgeQuery {
        all.along(line: line, tolerance: tolerance)
    }

    /// Selects edges running predominantly parallel to `direction`. See
    /// ``parallel(to:tolerance:)``.
    static func parallel(to direction: Direction3D, tolerance: Angle = 15°) -> EdgeQuery {
        all.parallel(to: direction, tolerance: tolerance)
    }

    /// Selects edges running predominantly parallel to `line`. See
    /// ``parallel(to:tolerance:)``.
    static func parallel(to line: Line3D, tolerance: Angle = 15°) -> EdgeQuery {
        all.parallel(to: line, tolerance: tolerance)
    }

    /// Selects edges running predominantly perpendicular to `axis`. See
    /// ``perpendicular(to:tolerance:)``.
    static func perpendicular(to axis: Axis3D, tolerance: Angle = 15°) -> EdgeQuery {
        all.perpendicular(to: axis, tolerance: tolerance)
    }

    /// Selects edges running predominantly perpendicular to `direction`. See
    /// ``perpendicular(to:tolerance:)``.
    static func perpendicular(to direction: Direction3D, tolerance: Angle = 15°) -> EdgeQuery {
        all.perpendicular(to: direction, tolerance: tolerance)
    }

    /// Selects edges running predominantly perpendicular to `line`. See
    /// ``perpendicular(line:tolerance:)``.
    static func perpendicular(line: Line3D, tolerance: Angle = 15°) -> EdgeQuery {
        all.perpendicular(line: line, tolerance: tolerance)
    }

    /// Selects edges entirely within the given box. See ``within(_:)-(BoundingBox3D)``.
    static func within(_ box: BoundingBox3D) -> EdgeQuery {
        all.within(box)
    }

    /// Selects edges whose every vertex falls within `range` along `axis`. See
    /// ``within(_:_:)``.
    static func within(_ axis: Axis3D, _ range: some WithinRange) -> EdgeQuery {
        all.within(axis, range)
    }

    /// Selects edges entirely within the given per-axis ranges. See ``within(x:y:z:)``.
    static func within(
        x: (any WithinRange)? = nil,
        y: (any WithinRange)? = nil,
        z: (any WithinRange)? = nil
    ) -> EdgeQuery {
        all.within(x: x, y: y, z: z)
    }

    /// Selects edges entirely within the given mask shape. See ``within(mask:)``.
    static func within(@GeometryBuilder3D mask: @Sendable @escaping () -> any Geometry3D) -> EdgeQuery {
        all.within(mask: mask)
    }

    /// Selects edges entirely above the given plane. See ``above(_:)``.
    static func above(_ plane: Plane) -> EdgeQuery {
        all.above(plane)
    }

    /// Selects edges entirely below the given plane. See ``below(_:)``.
    static func below(_ plane: Plane) -> EdgeQuery {
        all.below(plane)
    }

    /// Selects edges lying on the given plane. See ``on(_:tolerance:)``.
    static func on(_ plane: Plane, tolerance: Double = 0.01) -> EdgeQuery {
        all.on(plane, tolerance: tolerance)
    }

    /// Selects edges lying entirely within `radius` of `point`. See ``near(_:within:)``.
    static func near(_ point: Vector3D, within radius: Double) -> EdgeQuery {
        all.near(point, within: radius)
    }

    /// Selects closed (loop) edges. See ``closed``.
    static var closed: EdgeQuery {
        all.closed
    }

    /// Selects open (non-loop) edges. See ``open``.
    static var open: EdgeQuery {
        all.open
    }

    /// Selects convex (outside) edges. See ``convex``.
    static var convex: EdgeQuery {
        all.convex
    }

    /// Selects concave (inside corner) edges. See ``concave``.
    static var concave: EdgeQuery {
        all.concave
    }
}

// MARK: - Matching

internal extension EdgeQuery {
    /// - Parameter maskContainment: One containment lookup per entry in `maskConstraints`, in the
    ///   same order, mapping each candidate vertex position to whether it lies inside that mask.
    ///   Pass an empty array when the query has no mask constraints.
    func matches(_ edge: FoundEdge, maskContainment: [[Vector3D: Bool]] = []) -> Bool {
        if let directionalConstraint, !directionalConstraint.matches(edge) { return false }
        if !spatialConstraints.allSatisfy({ $0.matches(edge) }) { return false }
        if let topologyConstraint, !topologyConstraint.matches(edge) { return false }
        if let convexityConstraint, !convexityConstraint.matches(edge) { return false }
        if let lengthConstraint, !lengthConstraint.matches(edge) { return false }
        for lookup in maskContainment {
            if !edge.vertices.allSatisfy({ lookup[$0] ?? false }) { return false }
        }
        return true
    }
}

// MARK: - Constraint types

internal enum DirectionalConstraint: Sendable, Hashable, Codable {
    case parallel(Direction3D, tolerance: Angle)
    case perpendicular(to: Direction3D, tolerance: Angle)

    // The fraction of an edge's segments that must satisfy the constraint for the edge to match
    private static let requiredMatchingFraction = 0.7

    func matches(_ edge: FoundEdge) -> Bool {
        guard !edge.segments.isEmpty else { return false }
        let matchingCount = edge.segments.count { segment in
            let edgeDirection = segment.direction.unitVector
            switch self {
            case .parallel(let direction, let tolerance):
                return abs(edgeDirection ⋅ direction.unitVector) >= cos(tolerance)
            case .perpendicular(let direction, let tolerance):
                return abs(edgeDirection ⋅ direction.unitVector) <= sin(tolerance)
            }
        }
        return Double(matchingCount) / Double(edge.segments.count) > Self.requiredMatchingFraction
    }
}

internal enum SpatialConstraint: Sendable, Hashable, Codable {
    case withinBox(BoundingBox3D)
    case withinAxisRange(Axis3D, RangeBound)
    case onLine(Line3D, tolerance: Double)
    case onPlane(Plane, tolerance: Double)
    case nearPoint(Vector3D, radius: Double)
    case above(Plane)
    case below(Plane)

    private static let tolerance = 1e-6

    func matches(_ edge: FoundEdge) -> Bool {
        edge.vertices.allSatisfy { vertex in
            switch self {
            case .withinBox(let box):
                box.contains(vertex)
            case .withinAxisRange(let axis, let bound):
                bound.contains(vertex[axis])
            case .onLine(let line, let tolerance):
                line.distance(to: vertex) <= tolerance
            case .onPlane(let plane, let tolerance):
                abs(plane.distance(to: vertex)) <= tolerance
            case .nearPoint(let point, let radius):
                vertex.distance(to: point) <= radius
            case .above(let plane):
                plane.distance(to: vertex) >= -Self.tolerance
            case .below(let plane):
                plane.distance(to: vertex) <= Self.tolerance
            }
        }
    }
}

/// Wraps a mask geometry supplied to `within(mask:)`.
///
/// The geometry itself is excluded from `Hashable`/`Codable`/`Equatable` (see the conformances
/// below) — it can't be compared or serialized in general. Caching still works correctly because
/// `shapingEdges(_:matching:)`, the only cache-key consumer of `EdgeQuery`, separately evaluates
/// each mask into a `GeometryNode` and folds that node into the cache key itself. `EdgeQuery`'s own
/// conformances only need to distinguish "how many masks, in what combination with everything
/// else" — not the mask contents.
internal struct MaskConstraint: Sendable {
    let geometry: any Geometry3D
}

extension MaskConstraint: Hashable {
    static func == (lhs: MaskConstraint, rhs: MaskConstraint) -> Bool { true }
    func hash(into hasher: inout Hasher) {}
}

extension MaskConstraint: Codable {
    // Not meaningfully decodable; a decoded query's masks carry no usable geometry. Identity for
    // caching purposes comes from the separately-folded-in mask node, not from round-tripping this.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        _ = try container.decode(Bool.self)
        self.geometry = Empty<D3>()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(true)
    }
}

internal enum TopologyConstraint: Sendable, Hashable, Codable {
    case closed
    case open

    func matches(_ edge: FoundEdge) -> Bool {
        switch self {
        case .closed: edge.isClosed
        case .open: !edge.isClosed
        }
    }
}

internal enum ConvexityConstraint: Sendable, Hashable, Codable {
    case convex
    case concave

    func matches(_ edge: FoundEdge) -> Bool {
        switch self {
        case .convex: edge.isConvex
        case .concave: !edge.isConvex
        }
    }
}

internal struct LengthConstraint: Sendable, Hashable, Codable {
    let bound: RangeBound

    func matches(_ edge: FoundEdge) -> Bool {
        bound.contains(edge.length)
    }
}

/// A Hashable & Codable representation of a plain numeric range.
///
/// Stands in for `any WithinRange` so that `EdgeQuery` can be used as a cache key. Used both
/// for a range along a specific axis and for scalar ranges like edge length.
internal struct RangeBound: Hashable, Codable, Sendable {
    let lower: Double?   // nil = -∞
    let upper: Double?   // nil = +∞

    func contains(_ value: Double) -> Bool {
        (lower.map { value >= $0 } ?? true) && (upper.map { value <= $0 } ?? true)
    }

    init(_ range: some WithinRange) {
        switch range {
        case let range as ClosedRange<Double>:         lower = range.lowerBound; upper = range.upperBound
        case let range as Range<Double>:               lower = range.lowerBound; upper = range.upperBound
        case let range as PartialRangeFrom<Double>:    lower = range.lowerBound; upper = nil
        case let range as PartialRangeThrough<Double>: lower = nil;              upper = range.upperBound
        case let range as PartialRangeUpTo<Double>:    lower = nil;              upper = range.upperBound
        default:                                       lower = nil;              upper = nil
        }
    }
}
