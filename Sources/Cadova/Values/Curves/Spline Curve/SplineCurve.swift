import Foundation

/// A clamped, non‑uniform rational B‑spline (NURBS) curve.
///
/// The curve is defined by a degree `p ≥ 1`, a nondecreasing knot vector `U` of length `m+1`,
/// control points `P₀ … Pₙ` (with `n = controlPoints.count − 1`, `m = n + p + 1`), and positive
/// weights `w₀ … wₙ`. Setting all weights to `1` yields an ordinary (non‑rational) B‑spline.
///
public struct SplineCurve<V: Vector>: Sendable {
    let degree: Int
    let knots: [Double]
    let controlPoints: [(V, weight: Double)]
    
    /// Creates a clamped NURBS curve.
    ///
    /// - Parameters:
    ///   - degree: Curve degree `p` (≥ 1).
    ///   - knots: Nondecreasing knot vector. Must have length `n + p + 2`.
    ///   - controlPoints: Control points `P₀ … Pₙ` (count `n + 1`).
    ///   - weights: Positive weights `w₀ … wₙ`. If omitted, defaults to `1` for each control point.
    public init(degree: Int, knots: [Double], controlPoints: [(V, weight: Double)]) {
        precondition(degree >= 1, "Degree must be ≥ 1")
        precondition(!controlPoints.isEmpty, "Need at least one control point")
        precondition(knots.count == degree + controlPoints.count + 1, "Invalid knot count: expected degree + cp + 1")
        precondition(knots.isSortedNondecreasing, "Knots must be nondecreasing")
        precondition(controlPoints.allSatisfy { $0.weight > 0 && $0.weight.isFinite }, "Weights must be positive and finite")
        
        self.degree = degree
        self.knots = knots
        self.controlPoints = controlPoints
    }
    
    /// Evaluates the curve point at parameter `u` using homogeneous De Boor.
    public func point(at u: Double) -> V {
        let p = degree
        let span = findSpan(u: u)
        // Local homogeneous control points: (wP, w)
        var d: [(V, Double)] = (0...p).map { j in
            let idx = span - p + j
            let (p, w) = controlPoints[idx]
            return (p * w, w)
        }
        // De Boor in homogeneous space
        for r in 1...p {
            for j in stride(from: p, through: r, by: -1) {
                let i = span - p + j
                let denom = knots[i + p - r + 1] - knots[i]
                let alpha = denom.isZero ? 0 : (u - knots[i]) / denom
                let a = d[j - 1], b = d[j]
                d[j] = (a.0 * (1 - alpha) + b.0 * alpha, a.1 * (1 - alpha) + b.1 * alpha)
            }
        }
        let (Pw, w) = d[p]
        return Pw / w
    }
    
    /// Tangent direction via finite difference. Suitable for framing and sampling.
    public func tangent(at u: Double) -> Direction<V.D> {
        let eps = max(1e-6, 1e-6 * domain.length)
        let a = point(at: (u - eps).clamped(to: domain))
        let b = point(at: (u + eps).clamped(to: domain))
        return Direction(b - a)
    }
    
    /// Reversed curve (parameterization flipped). Knots, control points, and weights are mirrored accordingly.
    public func reversed() -> Self {
        let u0 = knots.first!, u1 = knots.last!
        let mirroredKnots = knots.map { u0 + u1 - $0 }.reversed()
        return SplineCurve(
            degree: degree,
            knots: Array(mirroredKnots),
            controlPoints: controlPoints.reversed()
        )
    }

    /// Maps all control points to a new vector type (weights unchanged).
    public func map<V2: Vector>(_ f: (V) -> V2) -> SplineCurve<V2> {
        .init(degree: degree, knots: knots, controlPoints: controlPoints.map { (p, w) in (f(p), w) })
    }

    /// Applies an affine transform to all control points (weights unchanged).
    public func transformed<T: Transform>(using transform: T) -> Self where T == V.D.Transform, T.V == V {
        map(transform.apply(to:))
    }
}

extension SplineCurve: ParametricCurve {
    public func points(segmentation: Segmentation) -> [V] {
        points(in: nil, segmentation: segmentation)
    }

    public var isEmpty: Bool { false }
    public var sampleCountForLengthApproximation: Int { controlPoints.count * 3 }

    public var domain: ClosedRange<Double> {
        knots[degree] ... knots[knots.count - degree - 1]
    }
    
    public var derivativeView: any CurveDerivativeView<V> {
        SplineCurveDerivativeView(splineCurve: self)
    }
    
    public func length(in range: ClosedRange<Double>?, segmentation: Segmentation) -> Double {
        points(in: range, segmentation: segmentation)
            .paired()
            .map { ($1 - $0).magnitude }
            .reduce(0, +)
    }
    
    public func mapPoints<Output: Vector>(_ transformer: (V) -> Output) -> any ParametricCurve<Output> {
        map(transformer)
    }
}

internal struct SplineCurveDerivativeView<V: Vector>: CurveDerivativeView {
    let splineCurve: SplineCurve<V>

    func tangent(at u: Double) -> Direction<V.D> {
        splineCurve.tangent(at: u)
    }
}

public extension SplineCurve {
    /// Samples points along the curve using a `Segmentation`.
    ///
    /// - Parameters:
    ///   - range: Optional parameter subrange to restrict sampling. If `nil`, the full `domain` is used.
    ///   - segmentation: The segmentation strategy.
    ///
    /// For `.fixed`, samples `n` segments uniformly in parameter space.
    /// For `.adaptive`, recursively subdivides parameter intervals based on chord length.
    ///
    func points(in range: ClosedRange<Double>? = nil, segmentation: Segmentation) -> [V] {
        let span = (range ?? domain).clamped(to: domain)

        switch segmentation {
        case .fixed(let n):
            let n = max(1, n)
            return (0...n).map { i in
                point(at: span.lowerBound + span.length * Double(i) / Double(n))
            }

        case .adaptive(_, let minSize):
            var out: [V] = []

            func subdivide(_ a: Double, _ b: Double, _ pa: V, _ pb: V) {
                let mid = 0.5 * (a + b)
                let pm = point(at: mid)

                let chord = (pb - pa).magnitude
                let approx = (pm - pa).magnitude + (pb - pm).magnitude

                if max(chord, approx - chord) < minSize {
                    out.append(pa)
                } else {
                    subdivide(a, mid, pa, pm)
                    subdivide(mid, b, pm, pb)
                }
            }

            let pa = point(at: span.lowerBound), pb = point(at: span.upperBound)
            subdivide(span.lowerBound, span.upperBound, pa, pb)
            out.append(pb)
            return out
        }
    }
}

private extension SplineCurve {
    // Finds i such that u ∈ [U[i], U[i+1]), with special case at the right end.
    func findSpan(u: Double) -> Int {
        let p = degree
        let n = controlPoints.count - 1
        let U = knots
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
}

public extension SplineCurve {
    func withWeight(_ weight: Double, forControlPointAtIndex index: Int) -> Self {
        precondition(weight > 0 && weight.isFinite, "Weights must be positive and finite")
        
        var controlPoints = self.controlPoints
        controlPoints[index].weight = weight
        return Self(degree: degree, knots: knots, controlPoints: controlPoints)
    }
    
    /// Creates a **uniform clamped cubic** NURBS from control points.
    ///
    /// Knots are `[0,0,0,0, 1/k, 2/k, …, 1, 1,1,1]` where `k = n − p + 1` (internal spans).
    /// If `weights` is omitted, all weights default to `1` (ordinary B‑spline behavior).
    static func uniformCubic(controlPoints: [V]) -> SplineCurve {
        let p = 3
        let n = controlPoints.count - 1
        precondition(n >= p, "Need at least p+1 control points")
        
        let k = n - p + 1
        let interior = (1..<k).map { Double($0) / Double(k) }
        let U = Array(repeating: 0.0, count: p + 1) + interior + Array(repeating: 1.0, count: p + 1)
        return SplineCurve(degree: p, knots: U, controlPoints: controlPoints.map { ($0, 1) })
    }
}
