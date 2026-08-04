import Foundation

// Mirrors every modifier in EdgeQuery+Modifiers.swift as a static factory/var starting from
// `.all`, so a query can begin directly with whichever criterion matters — `.convex` rather
// than `.all.convex` — without requiring an arbitrary named prefix to kick off the chain.

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
