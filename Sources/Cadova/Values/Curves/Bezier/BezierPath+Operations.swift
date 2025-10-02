import Foundation

public extension BezierPath {
    /// A typealias representing a fraction along a Bézier path.
    ///
    /// `BezierPath.Fraction` is a `Double` value that represents a fractional position along a Bézier path.
    /// The integer part of the value represents the index of the Bézier curve within the path,
    /// and the fractional part represents a position within that specific curve.
    ///
    /// For example:
    /// - `0.0` represents the start of the first curve.
    /// - `1.0` represents the start of the second curve.
    /// - `1.5` represents the midpoint of the second curve.
    ///
    /// This type is used for navigating and interpolating points along a multi-curve Bézier path.
    /// Fractions outside the full `fractionRange` can be used to extrapolate outside the normal path.
    ///
    typealias Fraction = Double

    /// The full range of fractions within this path
    var fractionRange: ClosedRange<Fraction> {
        0...Fraction(curves.count)
    }

    /// Applies the given 2D affine transform to the `BezierPath`.
    ///
    /// - Parameter transform: The affine transform to apply.
    /// - Returns: A new `BezierPath` instance with the transformed points.
    func transformed<T: Transform>(using transform: T) -> BezierPath where T.V == V, T == V.D.Transform {
        BezierPath(
            startPoint: transform.apply(to: startPoint),
            curves: curves.map { $0.transformed(using: transform) }
        )
    }

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

    /// Calculates the total length of the Bézier path.
    ///
    /// - Parameter segmentation: The desired level of detail for the generated points, which influences the accuracy
    ///   of the length calculation. More detailed segmentation results in more points being generated, leading to a
    ///   more accurate length approximation.
    /// - Returns: A `Double` value representing the total length of the Bézier path.
    func length(segmentation: Segmentation) -> Double {
        points(segmentation: segmentation)
            .paired()
            .map { ($1 - $0).magnitude }
            .reduce(0, +)
    }

    /// Returns the point at a specific fractional position along the path.
    ///
    /// - Parameter fraction: A fractional value indicating the position along the path.
    ///   The integer part indicates the curve index; the fractional part specifies the location within that curve.
    /// - Returns: The interpolated point along the path at the specified position.
    func point(at fraction: Fraction) -> V {
        guard !isEmpty else { return startPoint }
        let (curveIndex, t) = curveIndexAndFraction(for: fraction)
        return curves[curveIndex].point(at: t)
    }

    /// Accesses the point at a specific fractional position along the path.
    ///
    /// - Parameter fraction: A fractional value indicating the position along the path.
    /// - Returns: The point along the path at the specified position.
    subscript(fraction: Fraction) -> V {
        point(at: fraction)
    }

    /// Returns the tangent direction at a specific position along the path.
    ///
    /// - Parameter fraction: The fractional position along the path where the tangent is evaluated.
    /// - Returns: A `Direction` representing the tangent vector at the given position.
    func tangent(at fraction: Fraction) -> Direction<V.D> {
        Direction(derivative.point(at: fraction))
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
        curves.indices.flatMap { index in
            curves[index].points(segmentation: segmentation, subdividingStraightLines: false)
                .map(\.1)
                .dropFirst(index > 0 ? 1 : 0)
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
        curves.indices.flatMap { index in
            curves[index].points(segmentation: segmentation, subdividingStraightLines: true)
                .map(\.1)
                .dropFirst(index > 0 ? 1 : 0)
        }
    }

    /// Converts a sequence of points along the path into a custom geometry using a geometry builder.
    ///
    /// - Parameters:
    ///   - reader: A closure that transforms the points into a geometry value.
    /// - Returns: A constructed geometry object based on the sampled points.
    func readPoints<D: Dimensionality>(
        @GeometryBuilder<D> _ reader: @Sendable @escaping ([V]) -> D.Geometry
    ) -> D.Geometry {
        readEnvironment { e in
            reader(points(segmentation: e.segmentation))
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
    func mapPoints<V2: Vector>(_ transformer: (V) -> V2) -> BezierPath<V2> {
        BezierPath<V2>(
            startPoint: transformer(startPoint),
            curves: curves.map { $0.map(transformer) }
        )
    }
}

public extension BezierPath {
    internal func subpath(in range: ClosedRange<Fraction>) -> BezierPath {
        guard !isEmpty else { return self }
        let (lowerIndex, lowerFraction) = curveIndexAndFraction(for: range.lowerBound)
        var (upperIndex, upperFraction) = curveIndexAndFraction(for: range.upperBound)

        if upperIndex > 0, upperFraction < .ulpOfOne {
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

    /// Returns a new Bézier path covering the portion specified by `range`.
    ///
    /// The `range` follows the same `Fraction` convention used throughout the API:
    /// *Integer part* → curve index, *fractional part* → location within that curve.
    ///
    /// ### Examples
    /// ```swift
    /// // From 1½ curves in, through 3 curves in.
    /// let segment1 = path[1.5...3.0]
    ///
    /// // Partial from: start 1¼ curves in and continue to the end.
    /// let segment2 = path[1.25...]
    ///
    /// // Partial through: from the start up to *and including* 2 curves in.
    /// let segment3 = path[...2.0]
    /// ```
    ///
    /// Positions outside the full `fractionRange` are permitted and will extrapolate
    /// beyond the path’s usual bounds.
    ///
    subscript(range: any RangeExpression<Fraction>) -> BezierPath {
        subpath(in: range.resolved(with: fractionRange))
    }
}
