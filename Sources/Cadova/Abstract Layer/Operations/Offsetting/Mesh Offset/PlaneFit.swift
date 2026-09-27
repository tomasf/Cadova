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
        let (values, vectors) = Self.eigenDecomposition(matrix)
        let largest = values.map(abs).max() ?? 0
        var x = mean
        for k in 0..<3 where abs(values[k]) > Self.eigenvalueCutoff * largest {
            x = x + vectors[k] * ((vectors[k] ⋅ residual) / values[k])
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

    /// Eigenvalues and unit eigenvectors of a symmetric 3x3 matrix, by Jacobi rotations
    private static func eigenDecomposition(_ m: (Double, Double, Double, Double, Double, Double)) -> ([Double], [Vector3D]) {
        var a = [[m.0, m.1, m.2], [m.1, m.3, m.4], [m.2, m.4, m.5]]
        var v = [[1.0, 0, 0], [0, 1.0, 0], [0, 0, 1.0]]
        for _ in 0..<32 {
            let off = a[0][1] * a[0][1] + a[0][2] * a[0][2] + a[1][2] * a[1][2]
            if off < 1e-30 { break }
            for (p, q) in [(0, 1), (0, 2), (1, 2)] where abs(a[p][q]) > 1e-300 {
                let theta = (a[q][q] - a[p][p]) / (2 * a[p][q])
                let t = (theta >= 0 ? 1.0 : -1.0) / (abs(theta) + (theta * theta + 1).squareRoot())
                let c = 1 / (t * t + 1).squareRoot(), s = t * c
                for k in 0..<3 {
                    let akp = a[k][p], akq = a[k][q]
                    a[k][p] = c * akp - s * akq
                    a[k][q] = s * akp + c * akq
                }
                for k in 0..<3 {
                    let apk = a[p][k], aqk = a[q][k]
                    a[p][k] = c * apk - s * aqk
                    a[q][k] = s * apk + c * aqk
                }
                for k in 0..<3 {
                    let vkp = v[k][p], vkq = v[k][q]
                    v[k][p] = c * vkp - s * vkq
                    v[k][q] = s * vkp + c * vkq
                }
            }
        }
        let values = [a[0][0], a[1][1], a[2][2]]
        let vectors = (0..<3).map { k in Vector3D(v[0][k], v[1][k], v[2][k]) }
        return (values, vectors)
    }
}
