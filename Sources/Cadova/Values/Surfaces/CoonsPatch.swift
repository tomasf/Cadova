import Foundation

/// A smooth surface filling the area bounded by four curves.
///
/// A Coons patch is the standard way to fill a four-sided curved boundary: give it the four edges and it builds
/// a smooth surface that runs exactly along all of them, blending each pair of opposite edges across the patch.
/// Unlike a ``BezierPatch``, you don't place any interior control points; the boundary alone decides the shape.
/// The edges can be any curves, such as Bézier paths, splines, arcs or straight lines, and they don't need to be
/// of the same kind.
///
/// The four curves are given in order around the boundary, each starting where the previous one ends, with the
/// last one ending where the first one starts:
///
/// ```swift
/// let front = BezierPath3D(from: [0, 0, 0]) {
///     curve(controlX: 20, controlY: -10, controlZ: 10, endX: 40, endY: 0, endZ: 0)
/// }
/// let right = BezierPath3D(from: [40, 0, 0]) {
///     curve(controlX: 45, controlY: 20, controlZ: 5, endX: 40, endY: 40, endZ: 0)
/// }
/// let back = BezierPath3D(from: [40, 40, 0]) {
///     curve(controlX: 20, controlY: 50, controlZ: 15, endX: 0, endY: 40, endZ: 0)
/// }
/// let left = BezierPath3D(linesBetween: [[0, 40, 0], [0, 0, 0]])
///
/// CoonsPatch(boundary: front, right, back, left)
///     .enclosed(against: .z(-5))
/// ```
///
/// Points along each edge are matched by the fraction of the edge's length, so the edges don't need matching
/// segment layouts. On the surface, `u` runs along the first curve and `v` along the second. 2D curves are placed
/// in the XY plane.
///
/// - SeeAlso: ``RuledSurface``
///
public struct CoonsPatch<
    Edge1: ParametricCurve<Vector3D>, Edge2: ParametricCurve<Vector3D>,
    Edge3: ParametricCurve<Vector3D>, Edge4: ParametricCurve<Vector3D>
>: ParametricSurface {
    let edge1: ArcLengthParameterization<Edge1>
    let edge2: ArcLengthParameterization<Edge2>
    let edge3: ArcLengthParameterization<Edge3>
    let edge4: ArcLengthParameterization<Edge4>

    /// Creates a surface filling the area bounded by four curves.
    ///
    /// - Parameters:
    ///   - edge1: The first edge of the boundary.
    ///   - edge2: The second edge, starting where `edge1` ends.
    ///   - edge3: The third edge, starting where `edge2` ends.
    ///   - edge4: The fourth edge, starting where `edge3` ends and ending where `edge1` starts.
    ///
    /// - Precondition: The curves form a closed loop: each one starts where the previous one ends.
    ///
    public init<A: ParametricCurve, B: ParametricCurve, C: ParametricCurve, D: ParametricCurve>(
        boundary edge1: A, _ edge2: B, _ edge3: C, _ edge4: D
    ) where A.Curve3D == Edge1, B.Curve3D == Edge2, C.Curve3D == Edge3, D.Curve3D == Edge4 {
        self.edge1 = ArcLengthParameterization(edge1.curve3D)
        self.edge2 = ArcLengthParameterization(edge2.curve3D)
        self.edge3 = ArcLengthParameterization(edge3.curve3D)
        self.edge4 = ArcLengthParameterization(edge4.curve3D)

        let joints = [
            (self.edge1.endPoint, self.edge2.startPoint),
            (self.edge2.endPoint, self.edge3.startPoint),
            (self.edge3.endPoint, self.edge4.startPoint),
            (self.edge4.endPoint, self.edge1.startPoint),
        ]
        let scale = max(1, self.edge1.length, self.edge2.length, self.edge3.length, self.edge4.length)
        for (index, (end, start)) in joints.enumerated() {
            precondition(end.distance(to: start) <= 1e-6 * scale, """
                The boundary of a Coons patch must be a closed loop, but edge \(index + 1) ends at \(end) and \
                edge \((index + 1) % 4 + 1) starts at \(start). Each edge must start where the previous one ends.
                """)
        }
    }

    public func point(at uv: Vector2D) -> Vector3D {
        let u = uv.x, v = uv.y

        // The loop runs edge1 → edge2 → edge3 → edge4, so in (u, v) terms edge1 is v = 0 and edge2 is u = 1,
        // both running forward, while edge3 (v = 1) and edge4 (u = 0) run backward.
        let bottom = edge1.point(atFraction: u)
        let right = edge2.point(atFraction: v)
        let top = edge3.point(atFraction: 1 - u)
        let left = edge4.point(atFraction: 1 - v)

        let corner00 = edge1.startPoint
        let corner10 = edge2.startPoint
        let corner11 = edge3.startPoint
        let corner01 = edge4.startPoint

        // Blend each pair of opposite edges across the patch, then remove the bilinear blend of the corners,
        // which both of those blends include.
        let acrossV = bottom * (1 - v) + top * v
        let acrossU = left * (1 - u) + right * u
        let corners = corner00 * ((1 - u) * (1 - v)) + corner10 * (u * (1 - v))
            + corner01 * ((1 - u) * v) + corner11 * (u * v)
        return acrossV + acrossU - corners
    }
}
