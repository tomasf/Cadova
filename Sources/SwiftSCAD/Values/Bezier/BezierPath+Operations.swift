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

    /// Generates a sequence of points representing the path.
    ///
    /// - Parameter facets: The desired level of detail for the generated points, affecting the smoothness of curves.
    /// - Returns: An array of points that approximate the Bezier path.
    func points(facets: Environment.Facets) -> [V] {
        return [startPoint] + curves.flatMap {
            $0.points(facets: facets)[1...]
        }
    }

    /// Calculates the total length of the Bézier path.
    ///
    /// - Parameter facets: The desired level of detail for the generated points, which influences the accuracy
    ///   of the length calculation. More detailed facet values result in more points being generated, leading to a more
    ///   accurate length approximation.
    /// - Returns: A `Double` value representing the total length of the Bézier path.
    func length(facets: Environment.Facets) -> Double {
        points(facets: facets)
            .paired()
            .map { $0.distance(to: $1) }
            .reduce(0, +)
    }

    /// Applies the given 2D affine transform to the `BezierPath`.
    ///
    /// - Parameter transform: The affine transform to apply.
    /// - Returns: A new `BezierPath` instance with the transformed points.
    func transformed<T: AffineTransform>(using transform: T) -> BezierPath where T.Vector == V, T == V.Transform {
        BezierPath(
            startPoint: transform.apply(to: startPoint),
            curves: curves.map { $0.transformed(using: transform) }
        )
    }

    /// Returns the point at a given position along the path
    func point(at position: Position) -> V {
        assert(positionRange ~= position)
        guard !curves.isEmpty else { return startPoint }

        let curveIndex = min(Int(floor(position)), curves.count - 1)
        let fraction = position - Double(curveIndex)
        return curves[curveIndex].point(at: fraction)
    }

    internal func points(in pathFractionRange: ClosedRange<Position>, facets: Environment.Facets) -> [V] {
        let (fromCurveIndex, fromFraction) = pathFractionRange.lowerBound.indexAndFraction(curveCount: curves.count)
        let (toCurveIndex, toFraction) = pathFractionRange.upperBound.indexAndFraction(curveCount: curves.count)

        return curves[fromCurveIndex...toCurveIndex].enumerated().flatMap { index, curve in
            let startFraction = (index == fromCurveIndex) ? fromFraction : 0.0
            let endFraction = (index == toCurveIndex) ? toFraction : 1.0
            return curve.points(in: startFraction..<endFraction, facets: facets)
        }
    }


    /// Calculates the transformation when rotated and translated along the Bézier path up to a specified position.
    ///
    /// This method computes the transformation that includes both rotation and translation,
    /// as an object moves along the Bézier path up to a given position specified by `position`. The transformation
    /// accounts for the rotations necessary to align the object with the path's direction.
    ///
    /// - Parameters:
    ///   - position: The position along the path where the transformation is calculated. This value is of type
    ///   - facets: The desired level of detail for the generated points, affecting the smoothness and accuracy of the path traversal
    /// - Returns: A `V.Transform` representing the combined rotation and translation needed to move an object along the
    ///   Bézier path to the specified position.
    func transform(at position: Position, facets: Environment.Facets) -> V.Transform {
        guard !curves.isEmpty else { return .translation(startPoint) }
        return .init(
            points(in: 0...position, facets: facets).map(\.vector3D)
                .paired().map(-)
                .paired().map(AffineTransform3D.rotation(from:to:))
                .reduce(AffineTransform3D.identity) { $0.concatenated(with: $1) }
                .translated(point(at: position).vector3D)
        )
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
