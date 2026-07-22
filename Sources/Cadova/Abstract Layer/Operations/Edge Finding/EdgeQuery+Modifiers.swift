import Foundation

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
