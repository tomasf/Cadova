import Foundation

/// A smooth surface that passes through every point of a grid.
///
/// `InterpolatingSurface` is the surface counterpart of ``InterpolatingCurve``. Where a ``BezierPatch`` or
/// ``SplineSurface`` is only pulled toward its control points, this surface goes exactly through all of them, which
/// makes it the natural choice when you know points the surface must hit: measured heights, a sculpted shape
/// sketched as a grid, or values computed by your own code.
///
/// ```swift
/// // A 4×4 grid of heights over a 30 × 30 mm square
/// let heights: [[Double]] = [
///     [0, 2, 3, 1],
///     [1, 6, 8, 2],
///     [2, 7, 5, 3],
///     [0, 3, 2, 1],
/// ]
/// let grid = heights.enumerated().map { row, values in
///     values.enumerated().map { column, z in Vector3D(Double(column) * 10, Double(row) * 10, z) }
/// }
///
/// InterpolatingSurface(through: grid)
///     .enclosed(against: .z(-2))
/// ```
///
/// Each row of points becomes a Catmull–Rom curve, and a second Catmull–Rom curve runs across those at every point,
/// so the surface is smooth everywhere and reaches each grid point exactly. As with ``InterpolatingCurve``, a row
/// whose first and last points coincide is treated as a closed loop, and so is the grid as a whole when its last row
/// repeats its first.
///
/// On the surface, `u` runs across the rows and `v` along each row, the same way as for ``BezierPatch``. The grid
/// points sit at whole-number parameters: the point in row `i`, column `j` is at `(u, v) = (i, j)`, the same way
/// as for ``InterpolatingCurve``.
///
public struct InterpolatingSurface: ParametricSurface {
    let rows: [InterpolatingCurve<Vector3D>]
    let isClosedAcrossRows: Bool

    /// Creates a surface passing through a grid of points.
    ///
    /// - Parameter points: The rows of points. There must be at least two rows, each with at least two points,
    ///   and all rows must have the same number of points.
    public init(through points: [[Vector3D]]) {
        precondition(points.count >= 2, "An interpolating surface needs at least two rows of points")
        let columnCount = points[0].count
        precondition(columnCount >= 2, "Each row needs at least two points")
        precondition(points.allSatisfy { $0.count == columnCount }, "All rows must have the same number of points")

        rows = points.map { InterpolatingCurve(through: $0) }
        // The curves across the rows are built anew for every point, so their closure is decided once here, for
        // the whole grid: only a grid whose last row repeats its first wraps around.
        isClosedAcrossRows = zip(points.first!, points.last!).allSatisfy { $0.distance(to: $1) < 1e-6 }
    }

    /// The range of `u` values the surface accepts: `0` at the first row to the number of rows minus one at the last.
    public var uDomain: ClosedRange<Double> {
        0...Double(rows.count - 1)
    }

    /// The range of `v` values the surface accepts: `0` at the first point of each row to the number of points minus
    /// one at the last.
    public var vDomain: ClosedRange<Double> {
        rows[0].domain
    }

    /// Returns the point on the surface at the given parameters.
    ///
    /// - Parameter uv: The surface parameters, with `u` (`x`) within ``uDomain`` and `v` (`y`) within
    ///   ``vDomain``.
    /// - Returns: The point on the surface.
    public func point(at uv: Vector2D) -> Vector3D {
        InterpolatingCurve(through: rows.map { $0.point(at: uv.y) }, closed: isClosedAcrossRows).point(at: uv.x)
    }
}
