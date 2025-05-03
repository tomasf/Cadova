import Foundation

/// A mathematical representation of an infinite line in the given dimensionality.
///
/// A line is defined by a point through which it passes, and a direction indicating its orientation.
public struct Line<D: Dimensionality>: Sendable, Hashable {
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

public extension Line {
    /// Creates a line that passes through two points.
    ///
    /// - Parameters:
    ///   - from: The starting point.
    ///   - to: A second point, defining the direction of the line.
    init(from: D.Vector, to: D.Vector) {
        self.init(point: from, direction: .init(from: from, to: to))
    }

    /// Returns a point on the line at the given scalar multiple of the direction.
    /// For `t = 0`, returns the base `point`. For `t = 1`, returns one unit in the `direction`, and so on.
    func point(at t: Double) -> D.Vector {
        point + direction.unitVector * t
    }

    /// Checks whether a given point lies on the line, within a small tolerance.
    /// - Parameters:
    ///   - candidate: The point to test.
    ///
    func contains(_ candidate: D.Vector) -> Bool {
        let offset = candidate - point
        let dir = direction.unitVector

        // If the offset is zero, it's trivially on the line
        if offset.magnitude < 1e-6 { return true }

        let ratio = offset / dir
        let reference = ratio.first!
        return ratio.allSatisfy { Swift.abs($0 - reference) < 1e-6 }
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
}

public extension Line<D2> {
    /// Computes the intersection point with another line, if one exists.
    ///
    /// - Parameter other: Another line to intersect with.
    /// - Returns: The point of intersection, or `nil` if the lines are parallel or do not intersect.
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
}
