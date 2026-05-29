import Foundation

/// A finite straight segment defined by two endpoints in the given dimensionality.
///
/// Unlike ``Line``, which extends infinitely in both directions, a `LineSegment` has a defined
/// start and end and a finite length.
public struct LineSegment<D: Dimensionality>: Sendable, Hashable, Codable {
    /// The starting endpoint of the segment.
    public let start: D.Vector

    /// The ending endpoint of the segment.
    public let end: D.Vector

    /// Creates a segment from `start` to `end`.
    public init(from start: D.Vector, to end: D.Vector) {
        self.start = start
        self.end = end
    }

    /// The unit direction from `start` to `end`.
    public var direction: D.Direction {
        .init(from: start, to: end)
    }

    /// The Euclidean distance from `start` to `end`.
    public var length: Double {
        (end - start).magnitude
    }

    /// The point at parametric position `t`, where `0` returns `start` and `1` returns `end`.
    public func point(at t: Double) -> D.Vector {
        start + (end - start) * t
    }

    /// The infinite line that this segment lies on.
    public var line: Line<D> {
        Line(from: start, to: end)
    }
}

public typealias LineSegment2D = LineSegment<D2>
public typealias LineSegment3D = LineSegment<D3>
