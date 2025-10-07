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
    var isEmpty: Bool {
        curves.isEmpty
    }

    /// Returns the point at a specific fractional position along the path.
    ///
    /// - Parameter fraction: A fractional value indicating the position along the path.
    ///   The integer part indicates the curve index; the fractional part specifies the location within that curve.
    /// - Returns: The interpolated point along the path at the specified position.
    func point(at fraction: Double) -> V {
        guard !isEmpty else { return startPoint }
        let (curveIndex, t) = curveIndexAndFraction(for: fraction)
        return curves[curveIndex].point(at: t)
    }

    /// Computes the derivative path of the Bézier path.
    ///
    /// - Returns: A new `BezierPath` where each curve is replaced by its derivative.
    var derivative: BezierPath {
        BezierPath(startPoint: startPoint, curves: curves.map { $0.derivative })
    }

    /// Generates a sequence of points representing the path by sampling each curve.
    ///
    /// Straight line segments are represented minimally (start/end only); they are not subdivided.
    /// Use ``subdividedPoints(segmentation:)`` to subdivide straight segments as well.
    ///
    /// - Parameter segmentation: The desired level of detail for the generated points, affecting the smoothness of curves.
    /// - Returns: An array of points that approximate the Bézier path.
    /// - SeeAlso: ``subdividedPoints(segmentation:)``
    ///
    func points(segmentation: Segmentation) -> [V] {
        [startPoint] + curves.flatMap {
            $0.points(segmentation: segmentation, subdividingStraightLines: false)
                .dropFirst(1).map(\.1)
        }
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

public extension BezierPath {
    internal func subpath(in range: ClosedRange<Double>) -> BezierPath {
        guard !isEmpty else { return self }
        let (lowerIndex, lowerFraction) = curveIndexAndFraction(for: range.lowerBound)
        var (upperIndex, upperFraction) = curveIndexAndFraction(for: range.upperBound)

        if upperIndex > 0, upperFraction < Double.ulpOfOne {
            upperIndex -= 1
            upperFraction = 1.0
        }

        let newCurves: [BezierCurve<V>] = (lowerIndex...upperIndex).map { i in
            let start = (i == lowerIndex) ? lowerFraction : 0
            let end = (i == upperIndex) ? upperFraction : 1
            return (start == 0 && end == 1) ? curves[i] : curves[i].subcurve(in: start...end)
        }
        let newStartPoint = newCurves.first?.controlPoints[0] ?? startPoint
        return BezierPath(startPoint: newStartPoint, curves: newCurves)
    }
}
