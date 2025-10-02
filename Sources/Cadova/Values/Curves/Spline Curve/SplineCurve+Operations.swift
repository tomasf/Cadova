import Foundation

extension SplineCurve {
    /// Solves for `u` such that the `axis` component of the point at `u` is approximately `target`.
    ///
    /// - Important: Only works for monotonic curves in the axis direction.
    /// - Parameters:
    ///   - target: The target value to solve for.
    ///   - axis: The axis for the target value.
    /// - Returns: The value of `u` (not normalized) such that `point(at: u)[axis] ≈ target`, or `nil`
    ///   if not found. The returned `u` will lie within `parameterRange`.
    ///
    func u(for target: Double, in axis: V.D.Axis) -> Double? {
        let maxIterations = 8
        let tolerance = 1e-6

        let (u0, u1) = (domain.lowerBound, domain.upperBound)

        let a = point(at: u0)[axis]
        let b = point(at: u1)[axis]

        // Initial guess by linear interpolation of the axis value across the endpoints.
        var u = u0 + ((target - a) / (b - a)) * (u1 - u0)
        guard u.isFinite else { return nil }

        // Small step for finite-difference derivative in parameter space.
        let eps = max(1e-6, 1e-6 * (u1 - u0))

        for _ in 0..<maxIterations {
            let value = point(at: u)[axis]
            let error = value - target
            if Swift.abs(error) < tolerance {
                return u
            }

            // Axis derivative d/du using centered finite difference.
            let uMinus = (u - eps).clamped(to: domain)
            let uPlus  = (u + eps).clamped(to: domain)
            let dv = (point(at: uPlus)[axis] - point(at: uMinus)[axis]) / (uPlus - uMinus)

            guard Swift.abs(dv) > 1e-10 else {
                break // Avoid division by ~zero; monotonicity likely violated or curve is too flat.
            }

            u -= error / dv
            u = u.clamped(to: domain)
        }

        return nil
    }
}
