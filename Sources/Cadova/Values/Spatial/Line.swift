import Foundation

/// A mathematical representation of an infinite line in the given dimensionality.
///
/// A line is defined by a point through which it passes, and a direction indicating its orientation.
public struct Line<D: Dimensionality>: Sendable, Hashable, Codable {
    /// A point on the line.
    public let point: D.Vector

    /// The direction of the line
    public let direction: D.Direction

    /// Creates a line that passes through the given point in the specified direction.
    ///
    /// - Parameters:
    ///   - point: A point on the line.
    ///   - direction: The direction of the line
    public init(point: D.Vector, direction: D.Direction) {
        self.point = point
        self.direction = direction
    }
}

public typealias Line3D = Line<D3>
public typealias Line2D = Line<D2>

public extension Line {
    /// Creates a line that passes through two points.
    ///
    /// - Parameters:
    ///   - from: The starting point.
    ///   - to: A second point, defining the direction of the line.
    init(from: D.Vector, to: D.Vector) {
        self.init(point: from, direction: .init(from: from, to: to))
    }

    /// Creates a line aligned with one of the primary axes.
    ///
    /// The resulting line starts at the given offset and extends infinitely along the specified axis.
    ///
    /// - Parameters:
    ///   - axis: The axis along which the line extends.
    ///   - offset: The starting point of the line. Defaults to the origin.
    init(axis: D.Axis, offset: D.Vector = .zero) {
        self.init(point: offset, direction: .init(axis, .positive))
    }

    /// Returns a point on the line at the given scalar multiple of the direction.
    /// For `t = 0`, returns the base `point`. For `t = 1`, returns one unit in the `direction`, and so on.
    func point(at t: Double) -> D.Vector {
        point + direction.unitVector * t
    }

    /// Checks whether a given point lies on the line, within a small tolerance.
    /// - Parameters:
    ///   - candidate: The point to test.
    func contains(_ candidate: D.Vector) -> Bool {
        let offset = candidate - point
        if offset.magnitude < 1e-6 { return true }

        // Project the offset onto the direction
        let dir = direction.unitVector
        let projected = dir * ((offset ⋅ dir) / (dir ⋅ dir))
        return (projected - offset).magnitude < 1e-6
    }

    /// Returns the closest point on the line to the given external point.
    ///
    /// - Parameter external: The point to project onto the line.
    /// - Returns: The point on the line that is closest to the given point.
    func closestPoint(to external: D.Vector) -> D.Vector {
        let dir = direction.unitVector
        return point + dir * ((external - point) ⋅ dir)
    }

    /// Computes the shortest distance from the given point to this line.
    ///
    /// This is the length of the perpendicular from the point to the line.
    ///
    /// - Parameter external: The point from which to measure the distance.
    /// - Returns: The distance from the given point to the line.
    func distance(to external: D.Vector) -> Double {
        (external - closestPoint(to: external)).magnitude
    }

    /// Returns a new line translated by the given vector.
    ///
    /// - Parameter offset: The vector by which to translate the line.
    /// - Returns: A new translated line.
    func translated(by offset: D.Vector) -> Line {
        Line(point: point + offset, direction: direction)
    }
}

public extension Line<D2> {
    /// Returns a new line translated by the given x and y amounts.
    ///
    /// - Parameters:
    ///   - x: The amount to translate in the x direction (default 0).
    ///   - y: The amount to translate in the y direction (default 0).
    /// - Returns: A new translated line.
    func translated(x: Double = 0, y: Double = 0) -> Line {
        translated(by: D.Vector(x, y))
    }

    /// Returns a new line with the direction rotated using the provided rotation.
    ///
    /// This applies the rotation to both the point and the direction.
    ///
    /// - Parameter rotation: The rotation to apply.
    /// - Returns: A new rotated line.
    func rotated(by rotation: Angle) -> Line {
        Line(point: point, direction: direction.rotated(rotation))
    }

    /// Computes the intersection point with another line, if one exists.
    ///
    /// - Parameter other: Another line to intersect with.
    /// - Returns: The point of intersection, or `nil` if the lines are parallel.
    func intersection(with other: Line<D>) -> D.Vector? {
        let p = point
        let r = direction.unitVector
        let q = other.point
        let s = other.direction.unitVector

        let cross = r.x * s.y - r.y * s.x
        if Swift.abs(cross) < 1e-10 {
            return nil // Lines are parallel
        }

        let t = ((q - p).x * s.y - (q - p).y * s.x) / cross
        return p + r * t
    }

    /// Offsets the line by a signed distance, keeping the same direction.
    ///
    /// Positive amounts move the line to its clockwise side relative to its direction.
    /// Reversing the line's direction flips the offset side.
    ///
    /// - Parameter amount: The signed offset distance.
    /// - Returns: A new line parallel to this one, at the given distance.
    func offset(_ amount: Double) -> Line {
        Line(point: point + direction.clockwiseNormal.unitVector * amount, direction: direction)
    }

    /// A line extending along the X axis from the origin.
    static let x = Line(axis: .x)
    /// A line extending along the Y axis from the origin.
    static let y = Line(axis: .y)
}

public extension Line<D3> {
    /// Returns a new line translated by the given x, y, and z amounts.
    ///
    /// - Parameters:
    ///   - x: The amount to translate in the x direction (default 0).
    ///   - y: The amount to translate in the y direction (default 0).
    ///   - z: The amount to translate in the z direction (default 0).
    /// - Returns: A new translated line.
    func translated(x: Double = 0, y: Double = 0, z: Double = 0) -> Line {
        translated(by: D.Vector(x, y, z))
    }

    /// Returns a new line with the direction rotated by the specified angles around each axis.
    ///
    /// - Parameters:
    ///   - x: The rotation angle in degrees around the X axis.
    ///   - y: The rotation angle in degrees around the Y axis.
    ///   - z: The rotation angle in degrees around the Z axis.
    /// - Returns: A new line rotated by the given angles.
    func rotated(x: Angle = .zero, y: Angle = .zero, z: Angle = .zero) -> Line {
        Line(point: point, direction: direction.rotated(x: x, y: y, z: z))
    }

    /// A line extending along the X axis from the origin.
    static let x = Line(axis: .x)
    /// A line extending along the Y axis from the origin.
    static let y = Line(axis: .y)
    /// A line extending along the Z axis from the origin.
    static let z = Line(axis: .z)
}
