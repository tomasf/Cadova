import Foundation

public extension BezierPath {
    /// Returns a new `BezierPath` with all curves reversed in order and direction.
    ///
    /// - Returns: A new `BezierPath` with the start point and curves reversed.
    ///
    func reversed() -> Self {
        Self(startPoint: endPoint, curves: curves.reversed().map { $0.reversed() })
    }

    /// Returns a new `BezierPath` by appending another path to the current one.
    ///
    /// If the end point of the current path is the same as the start point of the other path,
    /// the two are connected directly. Otherwise, a straight line is added to bridge the gap
    /// before appending the other path's curves.
    ///
    /// - Parameter other: The path to append.
    /// - Returns: A new `BezierPath` that includes both the current path and the appended one.
    ///
    func appending(_ other: Self) -> Self {
        let distance = endPoint.distance(to: other.startPoint)
        let head = (distance < 1e-6) ? self : self.addingLine(to: other.startPoint)
        return BezierPath(startPoint: head.startPoint, curves: head.curves + other.curves)
    }
}

public extension BezierPath {
    /// Computes the derivative path of the Bézier path.
    ///
    /// - Returns: A new `BezierPath` where each curve is replaced by its derivative.
    var derivative: BezierPath {
        BezierPath(startPoint: startPoint, curves: curves.map { $0.derivative })
    }

    /// Samples the entire Bézier path, subdividing both curved and straight segments according to the given segmentation.
    ///
    /// This method produces a denser set of points than ``points(segmentation:)`` by also subdividing straight line segments.
    ///
    /// - Parameter segmentation: The desired level of detail for the generated points, influencing the density of the output.
    /// - Returns: An array of points representing the subdivided Bézier path, including both curved and straight segments.
    ///
    /// - SeeAlso: ``points(segmentation:)``
    ///
    func subdividedPoints(segmentation: Segmentation) -> [V] {
        [startPoint] + curves.flatMap {
            $0.points(segmentation: segmentation, subdividingStraightLines: true)
                .dropFirst(1).map(\.1)
        }
    }

    /// Returns a new `BezierPath` with each point transformed by the given closure.
    ///
    /// This method allows you to apply a custom transformation to all points in the path,
    /// including the starting point and all control points of each curve.
    ///
    /// - Parameter transformer: A closure that takes a point `V` and returns a transformed point `V2`.
    /// - Returns: A new `BezierPath` containing the transformed points.
    ///
    func map<V2: Vector>(_ transformer: (V) -> V2) -> BezierPath<V2> {
        BezierPath<V2>(
            startPoint: transformer(startPoint),
            curves: curves.map { $0.map(transformer) }
        )
    }
}
