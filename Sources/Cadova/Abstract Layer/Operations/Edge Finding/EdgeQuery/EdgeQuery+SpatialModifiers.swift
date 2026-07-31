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
}
