import Foundation

/// A clamped, non‑uniform rational B‑spline (NURBS) surface.
///
/// `SplineSurface` is the surface counterpart of ``SplineCurve``. It's shaped by a grid of weighted control points,
/// with a degree and a knot vector for each direction. Like a ``BezierPatch``, it's pulled toward its control points
/// and only passes through the four corner ones, but each control point only affects the part of the surface near
/// it, so large grids stay easy to shape locally.
///
/// Weights make the surface rational, which lets it describe conic shapes exactly. A quadratic arc with a middle
/// weight of `√2 / 2` is an exact quarter circle, so a surface built from such arcs is an exact section of a
/// cylinder, cone, sphere or torus, not an approximation of one:
///
/// ```swift
/// let w = sqrt(2) / 2
/// // A quarter cylinder: a circular arc in u, a straight line in v
/// SplineSurface(
///     uDegree: 2, vDegree: 1,
///     uKnots: [0, 0, 0, 1, 1, 1], vKnots: [0, 0, 1, 1],
///     controlPoints: [
///         [([10, 0, 0], weight: 1), ([10, 0, 20], weight: 1)],
///         [([10, 10, 0], weight: w), ([10, 10, 20], weight: w)],
///         [([0, 10, 0], weight: 1), ([0, 10, 20], weight: 1)],
///     ]
/// )
/// ```
///
/// For the common case of evenly spaced knots and no weights, use ``uniformCubic(controlPoints:)`` or
/// ``uniformClamped(degree:controlPoints:)``.
///
/// The control points are given as rows. On the surface, `u` runs across the rows and `v` along each row, the same
/// way as for ``BezierPatch``. Their domains are the ranges covered by the knot vectors, the same as for
/// ``SplineCurve``.
///
/// This is an advanced type. If you want a surface that passes through a grid of points, ``InterpolatingSurface``
/// is easier to use, and ``CoonsPatch`` fills a boundary of curves.
///
public struct SplineSurface: ParametricSurface {
    let uDegree: Int
    let uKnots: [Double]
    let rows: [SplineCurve<Vector3D>]

    /// Creates a NURBS surface.
    ///
    /// - Parameters:
    ///   - uDegree: The degree across the rows (≥ 1).
    ///   - vDegree: The degree along each row (≥ 1).
    ///   - uKnots: The nondecreasing knot vector across the rows. Its length must be the number of rows plus
    ///     `uDegree + 1`.
    ///   - vKnots: The nondecreasing knot vector along each row. Its length must be the number of points in a row
    ///     plus `vDegree + 1`.
    ///   - controlPoints: The rows of control points, each with a positive weight. All rows must have the same
    ///     number of points.
    ///
    public init(
        uDegree: Int, vDegree: Int,
        uKnots: [Double], vKnots: [Double],
        controlPoints: [[(Vector3D, weight: Double)]]
    ) {
        precondition(uDegree >= 1, "The u degree must be ≥ 1")
        precondition(!controlPoints.isEmpty, "A spline surface needs at least one row of control points")
        precondition(uKnots.count == uDegree + controlPoints.count + 1, "Invalid u knot count: expected u degree + rows + 1")
        precondition(uKnots.isSortedNondecreasing, "Knots must be nondecreasing")
        let columnCount = controlPoints[0].count
        precondition(controlPoints.allSatisfy { $0.count == columnCount }, "All rows must have the same number of control points")

        self.uDegree = uDegree
        self.uKnots = uKnots
        self.rows = controlPoints.map { SplineCurve(degree: vDegree, knots: vKnots, controlPoints: $0) }
    }

    /// The range of `u` values the surface accepts: the domain of the knot vector across the rows.
    public var uDomain: ClosedRange<Double> {
        uKnots[uDegree]...uKnots[uKnots.count - uDegree - 1]
    }

    /// The range of `v` values the surface accepts: the domain of the knot vector along each row.
    public var vDomain: ClosedRange<Double> {
        rows[0].domain
    }

    /// Returns the point on the surface at the given parameters.
    ///
    /// - Parameter uv: The surface parameters, `u` (`x`) and `v` (`y`). Outside ``uDomain`` and ``vDomain``,
    ///   the surface continues past its edges along its tangent planes.
    /// - Returns: The point on the surface.
    public func point(at uv: Vector2D) -> Vector3D {
        point(at: uv) { uv in
            // Evaluate each row in homogeneous coordinates, then run a curve across the rows. A row's result stands
            // in as a control point of that curve: its weight is the row's summed weight, and the curve multiplies
            // it back in, so the weighted sum carries through unchanged.
            let across = SplineCurve(degree: uDegree, knots: uKnots, controlPoints: rows.map { row in
                let (weightedPoint, weight) = row.homogeneousPoint(at: uv.y)
                return (weightedPoint / weight, weight: weight)
            })
            return across.point(at: uv.x)
        }
    }
}

public extension SplineSurface {
    /// Creates a uniform clamped cubic B‑spline surface from a grid of control points.
    ///
    /// The surface passes through the four corner control points and is pulled toward all the others without
    /// passing through them.
    ///
    /// - Parameter controlPoints: The rows of control points. There must be at least four rows, each with at least
    ///   four points.
    static func uniformCubic(controlPoints: [[Vector3D]]) -> Self {
        uniformClamped(degree: 3, controlPoints: controlPoints)
    }

    /// Creates a uniform clamped B‑spline surface of the given degree from a grid of control points.
    ///
    /// - Parameters:
    ///   - degree: The degree in both directions (≥ 1).
    ///   - controlPoints: The rows of control points. There must be more rows than `degree`, and more points in
    ///     each row than `degree`.
    static func uniformClamped(degree: Int, controlPoints: [[Vector3D]]) -> Self {
        precondition(!controlPoints.isEmpty, "A spline surface needs at least one row of control points")
        precondition(controlPoints.count > degree, "Need at least degree + 1 rows of control points")
        precondition(controlPoints[0].count > degree, "Need at least degree + 1 control points in each row")

        return Self(
            uDegree: degree, vDegree: degree,
            uKnots: uniformClampedKnots(degree: degree, controlPointCount: controlPoints.count),
            vKnots: uniformClampedKnots(degree: degree, controlPointCount: controlPoints[0].count),
            controlPoints: controlPoints.map { $0.map { ($0, weight: 1) } }
        )
    }
}

private extension SplineSurface {
    static func uniformClampedKnots(degree: Int, controlPointCount: Int) -> [Double] {
        let spans = controlPointCount - degree
        let interior = (1..<spans).map { Double($0) / Double(spans) }
        return Array(repeating: 0.0, count: degree + 1) + interior + Array(repeating: 1.0, count: degree + 1)
    }
}

extension SplineSurface: ParametricSurfacePieces {
    // One piece per knot span in each direction.
    var pieceCounts: (u: Int, v: Int) {
        (max(rows.count - uDegree, 1), max(rows[0].controlPoints.count - rows[0].degree, 1))
    }
}
