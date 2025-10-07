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
}

extension SplineCurve: ParametricCurve {
    /// Samples points along the curve using a `Segmentation`.
    ///
    /// - Parameters:
    ///   - segmentation: The segmentation strategy.
    ///
    /// For `.fixed`, samples `n` segments uniformly in parameter space.
    /// For `.adaptive`, recursively subdivides parameter intervals based on chord length.
    ///
    public func points(in range: ClosedRange<Double>, segmentation: Segmentation) -> [V] {
        let span = range.clamped(to: domain)

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


    public var isEmpty: Bool { false }
    public var sampleCountForLengthApproximation: Int { controlPoints.count * 3 }

    public var domain: ClosedRange<Double> {
        knots[degree]...knots[knots.count - degree - 1]
    }
    
    public var derivativeView: any CurveDerivativeView<V> {
        SplineCurveDerivativeView(splineCurve: self)
    }

    public func mapPoints(_ transformer: (V) -> Vector2D) -> SplineCurve<Vector2D> {
        map(transformer)
    }

    public func mapPoints(_ transformer: (V) -> Vector3D) -> SplineCurve<Vector3D> {
        map(transformer)
    }

    public var labeledControlPoints: [(V, label: String?)]? {
        controlPoints.enumerated().map(unpacked).map { controlPointIndex, controlPoint, weight in
            if weight - 1.0 > .ulpOfOne {
                (controlPoint, String(format: "%d (%g)", controlPointIndex, weight))
            } else {
                (controlPoint, "\(controlPointIndex)")
            }
        }
    }
}

internal struct SplineCurveDerivativeView<V: Vector>: CurveDerivativeView {
    let splineCurve: SplineCurve<V>

    func tangent(at u: Double) -> Direction<V.D> {
        splineCurve.tangent(at: u)
    }
}

public extension SplineCurve {
    func withWeight(_ weight: Double, forControlPointAtIndex index: Int) -> Self {
        precondition(weight > 0 && weight.isFinite, "Weights must be positive and finite")

        var controlPoints = self.controlPoints
        controlPoints[index].weight = weight
        return Self(degree: degree, knots: knots, controlPoints: controlPoints)
    }
}


extension SplineCurve: Transformable {
    /// Applies the given transform to the `SplineCurve`.
    ///
    /// - Parameter transform: The affine transform to apply.
    /// - Returns: A new `SplineCurve` instance with the transformed points.
    public func transformed(_ transform: V.D.Transform) -> SplineCurve {
        map(transform.apply(to:))
    }
}
