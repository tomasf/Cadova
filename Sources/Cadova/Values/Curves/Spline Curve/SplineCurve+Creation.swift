import Foundation

public extension SplineCurve {
    /// Creates a uniform clamped cubic NURBS from control points.
    ///
    /// Knots are `[0,0,0,0, 1/k, 2/k, …, 1, 1,1,1]` where `k = n − p + 1` (internal spans).
    ///
    static func uniformCubic(controlPoints: [V]) -> SplineCurve {
        uniformClamped(degree: 3, controlPoints: controlPoints)
    }

    /// Creates a uniform clamped quadratic NURBS from control points.
    ///
    /// Knots are `[0,0,0, 1/k, 2/k, …, 1,1,1]` where `k = n − p + 1`.
    ///
    static func uniformQuadratic(controlPoints: [V]) -> SplineCurve {
        uniformClamped(degree: 2, controlPoints: controlPoints)
    }

    /// Creates a uniform clamped spline of arbitrary degree.
    ///
    /// Knots are `[0,…,0, 1/k, 2/k, …, 1, …,1]` with multiplicity `degree+1` at each end.
    ///
    static func uniformClamped(degree: Int, controlPoints: [V]) -> SplineCurve {
        let n = controlPoints.count - 1
        precondition(n >= degree, "Need at least degree+1 control points")

        let k = n - degree + 1
        let interior = (1..<k).map { Double($0) / Double(k) }
        let U = Array(repeating: 0.0, count: degree + 1) + interior + Array(repeating: 1.0, count: degree + 1)
        return SplineCurve(degree: degree, knots: U, controlPoints: controlPoints.map { ($0, 1) })
    }
}
