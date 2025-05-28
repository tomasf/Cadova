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
    typealias Position = Double

    /// The valid range of positions within this path
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

    /// Returns the point at a given position along the path
    func point(at position: Position) -> V {
        //assert(positionRange ~= position)
        guard !curves.isEmpty else { return startPoint }

        var curveIndex = min(Int(floor(position)), curves.count - 1)
        var fraction = position - Double(curveIndex)
        if curveIndex < 0 {
            fraction += Double(curveIndex)
            curveIndex = 0
        }
        return curves[curveIndex].point(at: fraction)
    }

    /// Returns the point at a given position along the path
    subscript(position: Position) -> V {
        point(at: position)
    }

    func tangent(at position: Position) -> Direction<V.D> {
        assert(positionRange ~= position)
        let curveIndex = min(Int(floor(position)), curves.count - 1)
        let fraction = position - Double(curveIndex)
        return curves[curveIndex].tangent(at: fraction)
    }

    /// Generates a sequence of points representing the path.
    ///
    /// - Parameter segmentation: The desired level of detail for the generated points, affecting the smoothness of curves.
    /// - Returns: An array of points that approximate the Bezier path.
    func points(segmentation: EnvironmentValues.Segmentation) -> [V] {
        return [startPoint] + curves.flatMap {
            $0.points(segmentation: segmentation)[1...].map { $1 }
        }
    }

    /// Generates a sequence of points representing the path.
    ///
    /// - Parameter range: The position range in which to collect points
    /// - Parameter segmentation: The desired level of detail for the generated points, affecting the smoothness of curves.
    /// - Returns: An array of points that approximate the Bezier path.
    func points(in range: ClosedRange<Position>, segmentation: EnvironmentValues.Segmentation) -> [V] {
        pointsAtPositions(in: range, segmentation: segmentation).map(\.1)
    }

    func readPoints<D: Dimensionality>(
        in range: ClosedRange<Position>? = nil,
        @GeometryBuilder<D> _ reader: @Sendable @escaping ([V]) -> D.Geometry
    ) -> D.Geometry {
        readEnvironment { e in
            reader(points(in: range ?? positionRange, segmentation: e.segmentation))
        }
    }
}

internal extension BezierPath {
    func pointsAtPositions(in pathFractionRange: ClosedRange<Position>, segmentation: EnvironmentValues.Segmentation) -> [(Double, V)] {
        let (fromCurveIndex, fromFraction) = pathFractionRange.lowerBound.indexAndFraction(curveCount: curves.count)
        let (toCurveIndex, toFraction) = pathFractionRange.upperBound.indexAndFraction(curveCount: curves.count)

        return curves[fromCurveIndex...toCurveIndex].enumerated().flatMap { index, curve in
            let startFraction = (index == fromCurveIndex) ? fromFraction : 0.0
            let endFraction = (index == toCurveIndex) ? toFraction : 1.0
            let skipFirst = index > fromCurveIndex
            return curve.points(in: startFraction..<endFraction, segmentation: segmentation)
                .map { ($0 + Double(index), $1) }
                .dropFirst(skipFirst ? 1 : 0)
        }
    }

    func readPositionsAndPoints<D: Dimensionality>(
        in range: ClosedRange<Position>? = nil,
        reader: @Sendable @escaping ([(Double, V)]) -> D.Geometry
    ) -> D.Geometry {
        readEnvironment { e in
            reader(pointsAtPositions(in: range ?? positionRange, segmentation: e.segmentation))
        }
    }
}

// For paths that are monotonic over axis
internal extension BezierPath {
    func range(for axis: V.D.Axis) -> Range<Double> {
        guard let lastCurve = curves.last else { return 0..<0 }
        let lastPoint = lastCurve.controlPoints.last!
        return startPoint[axis]..<lastPoint[axis]
    }

    func curveIndex(for value: Double, in axis: V.D.Axis) -> Int {
        curves.firstIndex(where: {
            value <= $0.controlPoints.last![axis]
        }) ?? curves.count - 1
    }

    func position(for target: Double, in axis: V.D.Axis) -> Position? {
        let curveIndex = curveIndex(for: target, in: axis)
        guard let t = curves[curveIndex].t(for: target, in: axis) else {
            return nil
        }
        return Double(curveIndex) + t
    }
}

fileprivate extension BezierPath.Position {
    func indexAndFraction(curveCount: Int) -> (Int, Double) {
        if self < 0 {
            return (0, self)
        } else if self >= Double(curveCount) {
            return (curveCount - 1, self - Double(curveCount - 1))
        } else {
            let index = floor(self)
            let fraction = self - index
            return (Int(index), fraction)
        }
    }
}
