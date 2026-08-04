import Foundation

public extension EdgeQuery {
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
}
