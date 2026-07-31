import Foundation

public extension EdgeQuery {
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

    /// Returns a query that only accepts edges running predominantly along `axis`.
    ///
    /// - Parameters:
    ///   - axis: The axis to check alignment against.
    ///   - tolerance: How far from perfectly aligned a segment can be. Default 15°.
    func along(_ axis: Axis3D, tolerance: Angle = 15°) -> EdgeQuery {
        parallel(to: Direction3D(axis, .positive), tolerance: tolerance)
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
}
