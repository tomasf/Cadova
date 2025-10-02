import Foundation

public extension SplineCurve {
    /// Creates a Catmull–Rom–style interpolating curve (centripetal parameterization) as a clamped, non‑rational cubic spline.
    ///
    /// The resulting `SplineCurve` passes through all provided sample points. Internally this performs
    /// global B‑spline interpolation with cubic degree (`p = 3`), centripetal parameterization (α = `alpha`),
    /// and knots computed by the standard averaging rule. All weights are `1.0` (non‑rational).
    ///
    /// - Parameters:
    ///   - points: The data points the curve should pass through (must be ≥ 2).
    ///   - alpha:  The Catmull–Rom parameterization exponent: `0` (uniform), `0.5` (centripetal, default), `1` (chord length).
    /// - Returns: A cubic `SplineCurve` that interpolates `points`.
    ///
    static func catmullRom(_ points: [V], alpha: Double = 0.5) -> SplineCurve {
        precondition(points.count >= 2, "Need at least two points")
        let p = 3
        let n = points.count - 1
        if n == 1 {
            // Two points → just a cubic with four knots [0,0,0,0,1,1,1,1] and control points equal to the endpoints.
            return uniformCubic(controlPoints: points)
        }

        let u = parameterize(points, alpha: alpha)
        let U = averagedKnots(u: u, degree: p)

        // Build dense (n+1)×(n+1) coefficient matrix N and solve N * P = Q
        var N = Array(repeating: Array(repeating: 0.0, count: n + 1), count: n + 1)
        for i in 0...n {
            let span = findSpanStatic(u[i], degree: p, knots: U, controlPointCount: n + 1)
            let bf = basisFunctions(span: span, u: u[i], degree: p, knots: U)
            let j0 = span - p
            for j in 0...p {
                N[i][j0 + j] = bf[j]
            }
        }

        var Q = points
        let controlPoints = solveDense(&N, &Q)
        return SplineCurve(degree: p, knots: U, controlPoints: controlPoints.map { ($0, 1.0) })
    }
}

// MARK: - Catmull–Rom helpers

/// Centripetal/Chord/Uniform parameterization (α = 0.5 / 1 / 0)
fileprivate func parameterize<V: Vector>(_ pts: [V], alpha: Double) -> [Double] {
    let n = pts.count - 1
    var u = Array(repeating: 0.0, count: n + 1)
    var total = 0.0
    for i in 1...n {
        let d = (pts[i] - pts[i - 1]).magnitude
        let inc = pow(max(d, .ulpOfOne), alpha)
        u[i] = u[i - 1] + inc
        total += inc
    }
    if total > 0 {
        for i in 0...n { u[i] /= total }
    }
    u[n] = 1.0
    return u
}

/// Averaging rule for clamped cubic: U = [0,0,0,0, ū₄ … ū_{m-4}, 1,1,1,1]
fileprivate func averagedKnots(u: [Double], degree p: Int) -> [Double] {
    // Piegl & Tiller averaging rule for clamped cubic:
    // Internal knot count = n - p, with indices k = 1 ... n - p
    // U[p + k] = (u_k + u_{k+1} + u_{k+2}) / 3, where u_0 ... u_n
    let n = u.count - 1
    precondition(p == 3, "This helper assumes cubic (p=3)")

    // Start with p+1 zeros (left clamp)
    var U = Array(repeating: 0.0, count: p + 1)

    let interiorCount = n - p
    if interiorCount > 0 {
        for k in 1...interiorCount {
            let avg = (u[k] + u[k + 1] + u[k + 2]) / 3.0
            U.append(avg)
        }
    }

    // End with p+1 ones (right clamp)
    U += Array(repeating: 1.0, count: p + 1)
    return U
}

fileprivate func findSpanStatic(_ u: Double, degree p: Int, knots U: [Double], controlPointCount nPlus1: Int) -> Int {
    let n = nPlus1 - 1
    let uMin = U[p], uMax = U[n + 1]
    if u <= uMin { return p }
    if u >= uMax { return n }
    var low = p, high = n + 1, mid = (low + high) / 2
    while !(u >= U[mid] && u < U[mid + 1]) {
        if u < U[mid] { high = mid } else { low = mid }
        mid = (low + high) / 2
    }
    return mid
}

/// Basis functions N_{i-p..i,p}(u)
fileprivate func basisFunctions(span: Int, u: Double, degree p: Int, knots U: [Double]) -> [Double] {
    var N = Array(repeating: 0.0, count: p + 1)
    var left = Array(repeating: 0.0, count: p + 1)
    var right = Array(repeating: 0.0, count: p + 1)
    N[0] = 1.0
    for j in 1...p {
        left[j] = u - U[span + 1 - j]
        right[j] = U[span + j] - u
        var saved = 0.0
        for r in 0..<j {
            let temp = N[r] / (right[r + 1] + left[j - r])
            N[r] = saved + right[r + 1] * temp
            saved = left[j - r] * temp
        }
        N[j] = saved
    }
    return N
}

/// Dense Gaussian elimination with partial pivoting on a matrix `A` and RHS vector of `V`.
fileprivate func solveDense<V: Vector>(_ A: inout [[Double]], _ b: inout [V]) -> [V] {
    let n = b.count
    for k in 0..<n {
        // Pivot
        var pivot = k
        var maxVal = Swift.abs(A[k][k])
        for i in (k+1)..<n {
            let v = Swift.abs(A[i][k])
            if v > maxVal { maxVal = v; pivot = i }
        }
        if pivot != k {
            A.swapAt(k, pivot)
            b.swapAt(k, pivot)
        }
        let akk = A[k][k]
        precondition(Swift.abs(akk) > .ulpOfOne, "Singular system in spline interpolation")
        let inv = 1.0 / akk
        // Normalize row k
        for j in k..<n { A[k][j] *= inv }
        b[k] = b[k] * inv
        // Eliminate below
        for i in (k+1)..<n {
            let factor = A[i][k]
            if factor == 0 { continue }
            for j in k..<n { A[i][j] -= factor * A[k][j] }
            b[i] = b[i] - factor * b[k]
        }
    }
    // Back substitution
    var x = Array(repeating: b[0], count: n)
    for i in stride(from: n-1, through: 0, by: -1) {
        var sum = b[i]
        for j in (i+1)..<n {
            sum = sum - A[i][j] * x[j]
        }
        x[i] = sum
    }
    return x
}
