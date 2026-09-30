import Foundation

/// A least-squares fit of one point to a set of planes, each given by a point on it and its normal: the quadratic
/// error function of dual contouring.
///
/// The minimizer is solved around the planes' mean point with small eigenvalues dropped, so directions the planes
/// leave free (along a flat face, along a straight crease) stay at the mean point instead of drifting.
internal struct PlaneFit: Sendable {
    // Symmetric matrix of summed normal outer products, stored as xx, xy, xz, yy, yz, zz
    private var matrix: (Double, Double, Double, Double, Double, Double) = (0, 0, 0, 0, 0, 0)
    private var vector = Vector3D.zero
    private var constant = 0.0
    private var pointSum = Vector3D.zero
    private(set) var count = 0

    /// The fraction of the largest eigenvalue below which a direction counts as unconstrained
    static let eigenvalueCutoff = 0.02

    mutating func add(point: Vector3D, normal n: Vector3D) {
        matrix.0 += n.x * n.x; matrix.1 += n.x * n.y; matrix.2 += n.x * n.z
        matrix.3 += n.y * n.y; matrix.4 += n.y * n.z; matrix.5 += n.z * n.z
        let offset = n ⋅ point
        vector = vector + n * offset
        constant += offset * offset
        pointSum = pointSum + point
        count += 1
    }

    mutating func add(_ other: PlaneFit) {
        matrix.0 += other.matrix.0; matrix.1 += other.matrix.1; matrix.2 += other.matrix.2
        matrix.3 += other.matrix.3; matrix.4 += other.matrix.4; matrix.5 += other.matrix.5
        vector = vector + other.vector
        constant += other.constant
        pointSum = pointSum + other.pointSum
        count += other.count
    }

    var meanPoint: Vector3D { count > 0 ? pointSum / Double(count) : .zero }

    /// The angle the planes' normals span, in radians, estimated from how far they scatter around their main
    /// direction: normals spread evenly over an angle φ have a mean squared sine of about φ² / 12 from its middle
    var normalSpread: Double {
        guard count > 0 else { return 0 }
        let eigen = Self.eigenDecomposition(matrix)
        let largest = max(eigen.values.0, eigen.values.1, eigen.values.2)
        return (12 * max(0, 1 - largest / Double(count))).squareRoot()
    }

    private func multiply(_ x: Vector3D) -> Vector3D {
        Vector3D(
            matrix.0 * x.x + matrix.1 * x.y + matrix.2 * x.z,
            matrix.1 * x.x + matrix.3 * x.y + matrix.4 * x.z,
            matrix.2 * x.x + matrix.4 * x.y + matrix.5 * x.z
        )
    }

    /// Sum of squared distances from x to the planes
    func error(at x: Vector3D) -> Double {
        max(0, x ⋅ multiply(x) - 2 * (vector ⋅ x) + constant)
    }

    /// Root mean square distance from x to the planes
    func rootMeanSquareError(at x: Vector3D) -> Double {
        count > 0 ? (error(at: x) / Double(count)).squareRoot() : 0
    }

    /// The best fitting point
    func solve() -> Vector3D {
        let mean = meanPoint
        let residual = vector - multiply(mean)
        let eigen = Self.eigenDecomposition(matrix)
        let largest = max(abs(eigen.values.0), max(abs(eigen.values.1), abs(eigen.values.2)))
        var x = mean
        var k = 0
        while k < 3 {
            let value = eigen.value(k), vector = eigen.vector(k)
            if abs(value) > Self.eigenvalueCutoff * largest { x = x + vector * ((vector ⋅ residual) / value) }
            k += 1
        }
        return x
    }

    /// The best fitting point within a box, by projected gradient descent from the clamped mean point
    func solve(within lower: Vector3D, _ upper: Vector3D) -> Vector3D {
        func clamped(_ x: Vector3D) -> Vector3D { .min(.max(x, lower), upper) }
        let rowSums = [
            abs(matrix.0) + abs(matrix.1) + abs(matrix.2),
            abs(matrix.1) + abs(matrix.3) + abs(matrix.4),
            abs(matrix.2) + abs(matrix.4) + abs(matrix.5),
        ]
        let largest = rowSums.max() ?? 0
        var x = clamped(meanPoint)
        guard largest > 0 else { return x }
        let step = 1 / largest
        for _ in 0..<200 {
            let next = clamped(x - (multiply(x) - vector) * step)
            let moved = (next - x).magnitude
            x = next
            if moved < 1e-12 { break }
        }
        return x
    }

    struct EigenDecomposition {
        let values: (Double, Double, Double)
        let vectors: (Vector3D, Vector3D, Vector3D)

        func value(_ k: Int) -> Double { k == 0 ? values.0 : k == 1 ? values.1 : values.2 }
        func vector(_ k: Int) -> Vector3D { k == 0 ? vectors.0 : k == 1 ? vectors.1 : vectors.2 }
    }

    /// Eigenvalues and unit eigenvectors of a symmetric 3x3 matrix, by Jacobi rotations. Over one temporary buffer
    /// with counted loops: nested arrays and range iteration are slow in unoptimized builds, which run this millions
    /// of times.
    static func eigenDecomposition(_ m: (Double, Double, Double, Double, Double, Double)) -> EigenDecomposition {
        withUnsafeTemporaryAllocation(of: Double.self, capacity: 18) { buffer in
            let a = buffer.baseAddress!, v = a + 9   // row-major: a[row * 3 + column]
            a[0] = m.0; a[1] = m.1; a[2] = m.2
            a[3] = m.1; a[4] = m.3; a[5] = m.4
            a[6] = m.2; a[7] = m.4; a[8] = m.5
            var n = 0
            while n < 9 { v[n] = n % 4 == 0 ? 1 : 0; n += 1 }
            var sweep = 0
            while sweep < 32 {
                sweep += 1
                let off = a[1] * a[1] + a[2] * a[2] + a[5] * a[5]
                if off < 1e-30 { break }
                var pair = 0
                while pair < 3 {
                    let p = pair == 2 ? 1 : 0, q = pair == 0 ? 1 : 2
                    pair += 1
                    let apq = a[p * 3 + q]
                    if abs(apq) <= 1e-300 { continue }
                    let theta = (a[q * 3 + q] - a[p * 3 + p]) / (2 * apq)
                    let t = (theta >= 0 ? 1.0 : -1.0) / (abs(theta) + (theta * theta + 1).squareRoot())
                    let c = 1 / (t * t + 1).squareRoot(), s = t * c
                    var k = 0
                    while k < 3 {
                        let akp = a[k * 3 + p], akq = a[k * 3 + q]
                        a[k * 3 + p] = c * akp - s * akq
                        a[k * 3 + q] = s * akp + c * akq
                        k += 1
                    }
                    k = 0
                    while k < 3 {
                        let apk = a[p * 3 + k], aqk = a[q * 3 + k]
                        a[p * 3 + k] = c * apk - s * aqk
                        a[q * 3 + k] = s * apk + c * aqk
                        k += 1
                    }
                    k = 0
                    while k < 3 {
                        let vkp = v[k * 3 + p], vkq = v[k * 3 + q]
                        v[k * 3 + p] = c * vkp - s * vkq
                        v[k * 3 + q] = s * vkp + c * vkq
                        k += 1
                    }
                }
            }
            return EigenDecomposition(
                values: (a[0], a[4], a[8]),
                vectors: (Vector3D(v[0], v[3], v[6]), Vector3D(v[1], v[4], v[7]), Vector3D(v[2], v[5], v[8]))
            )
        }
    }
}
