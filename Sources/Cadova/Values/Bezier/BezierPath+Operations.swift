import Foundation

public extension BezierPath {
    /// A typealias representing a position along a Bézier path.
    ///
    /// `BezierPath.Position` is a `Double` value that represents a fractional position along a Bézier path.
    /// The integer part of the value represents the index of the Bézier curve within the path,
    /// and the fractional part represents a position within that specific curve.
    ///
    /// For example:
    /// - `0.0` represents the start of the first curve.
    /// - `1.0` represents the start of the second curve.
    /// - `1.5` represents the midpoint of the second curve.
    ///
    /// This type is used for navigating and interpolating points along a multi-curve Bézier path.
    /// Positions outside the full `positionRange` can be used to extrapolate outside the normal path.
    ///
    typealias Position = Double

    /// The full range of positions within this path
    var positionRange: ClosedRange<Position> {
        0...Position(curves.count)
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
}

public extension BezierPath {
    /// Calculates the total length of the Bézier path.
    ///
    /// - Parameter segmentation: The desired level of detail for the generated points, which influences the accuracy
    ///   of the length calculation. More detailed segmentation results in more points being generated, leading to a more
    ///   accurate length approximation.
    /// - Returns: A `Double` value representing the total length of the Bézier path.
    func length(segmentation: EnvironmentValues.Segmentation, in range: ClosedRange<Position>? = nil) -> Double {
        points(in: range ?? positionRange, segmentation: segmentation)
            .paired()
            .map { $0.distance(to: $1) }
            .reduce(0, +)
    }

    /// Returns the point at a specific fractional position along the path.
    ///
    /// - Parameter position: A fractional value indicating the position along the path.
    ///   The integer part indicates the curve index; the fractional part specifies the location within that curve.
    /// - Returns: The interpolated point along the path at the specified position.
    func point(at position: Position) -> V {
        guard !curves.isEmpty else { return startPoint }

        var curveIndex = min(Int(floor(position)), curves.count - 1)
        var fraction = position - Double(curveIndex)
        if curveIndex < 0 {
            fraction += Double(curveIndex)
            curveIndex = 0
        }
        return curves[curveIndex].point(at: fraction)
    }

    /// Accesses the point at a specific fractional position along the path.
    ///
    /// - Parameter position: A fractional value indicating the position along the path.
    /// - Returns: The point along the path at the specified position.
    subscript(position: Position) -> V {
        point(at: position)
    }

    /// Returns the tangent direction at a specific position along the path.
    ///
    /// - Parameter position: The fractional position along the path where the tangent is evaluated.
    /// - Returns: A `Direction` representing the tangent vector at the given position.
    func tangent(at position: Position) -> Direction<V.D> {
        Direction(derivative.point(at: position))
    }

    /// Computes the derivative path of the Bézier path.
    ///
    /// - Returns: A new `BezierPath` where each curve is replaced by its derivative.
    var derivative: BezierPath {
        BezierPath(startPoint: startPoint, curves: curves.map { $0.derivative })
    }

    /// Generates a sequence of points representing the path.
    ///
    /// - Parameter range: The position range in which to collect points
    /// - Parameter segmentation: The desired level of detail for the generated points, affecting the smoothness of curves.
    /// - Returns: An array of points that approximate the Bezier path.
    func points(in range: ClosedRange<Position>? = nil, segmentation: EnvironmentValues.Segmentation) -> [V] {
        pointsAtPositions(in: range ?? positionRange, segmentation: segmentation).map(\.1)
    }

    /// Converts a sequence of points along the path into a custom geometry using a geometry builder.
    ///
    /// - Parameters:
    ///   - range: Optional position range within the path to sample.
    ///   - reader: A closure that transforms the points into a geometry value.
    /// - Returns: A constructed geometry object based on the sampled points.
    func readPoints<D: Dimensionality>(
        in range: ClosedRange<Position>? = nil,
        @GeometryBuilder<D> _ reader: @Sendable @escaping ([V]) -> D.Geometry
    ) -> D.Geometry {
        readEnvironment { e in
            reader(points(in: range ?? positionRange, segmentation: e.segmentation))
        }
    }
}
