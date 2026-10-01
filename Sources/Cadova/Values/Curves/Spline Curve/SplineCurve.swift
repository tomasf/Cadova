import Foundation

/// A clamped, non‑uniform rational B‑spline (NURBS) curve.
///
/// The curve is defined by a degree `p ≥ 1`, a nondecreasing knot vector `U` of length `m+1`,
/// control points `P₀ … Pₙ` (with `n = controlPoints.count − 1`, `m = n + p + 1`), and positive
/// weights `w₀ … wₙ`. Setting all weights to `1` yields an ordinary (non‑rational) B‑spline.
///
public struct SplineCurve<V: Vector>: Sendable, Hashable, Codable {
    let degree: Int
    let knots: [Double]
    let controlPoints: [ControlPoint]

    internal struct ControlPoint: Sendable, Hashable, Codable {
        var point: V
        var weight: Double

        init(_ point: V, weight: Double) {
            self.point = point
            self.weight = weight
        }
    }

    /// Creates a clamped NURBS curve.
    ///
    /// - Parameters:
    ///   - degree: Curve degree `p` (≥ 1).
    ///   - knots: Nondecreasing knot vector. Must have length `n + p + 2`.
    ///   - controlPoints: Control points `P₀ … Pₙ` (count `n + 1`) with associated positive weights.
    ///
    public init(degree: Int, knots: [Double], controlPoints: [(V, weight: Double)]) {
        self.init(degree: degree, knots: knots, controlPoints: controlPoints.map {
            ControlPoint($0.0, weight: $0.weight)
        })
    }

    private init(degree: Int, knots: [Double], controlPoints: [ControlPoint]) {
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
        let (weightedPoint, weight) = homogeneousPoint(at: u)
        return weightedPoint / weight
    }

    /// Evaluates the curve at parameter `u` in homogeneous coordinates, before the division by weight.
    ///
    /// The result is the weighted point `Σ Nᵢ(u) wᵢ Pᵢ` together with the weight `Σ Nᵢ(u) wᵢ`. A NURBS surface
    /// evaluated one direction at a time has to carry both into the second direction; dividing early
    /// gives the wrong surface wherever the weights differ.
    internal func homogeneousPoint(at u: Double) -> (point: V, weight: Double) {
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
            let p = controlPoints[span - p + j]
            return (p.point * p.weight, p.weight)
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
        return (d[p].0, d[p].1)
    }
    
    /// Tangent direction via finite difference. Suitable for framing and sampling.
    ///
    /// Repeated control points can leave the curve stationary across a whole knot span, where a plain
    /// difference is exactly zero. The sampling window is widened until it finds real geometry instead
    /// of normalizing that zero.
    public func tangent(at u: Double) -> Direction<V.D> {
        finiteDifferenceTangent(at: u, baseStep: max(1e-6, 1e-6 * domain.length))
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
        .init(degree: degree, knots: knots, controlPoints: controlPoints.map {
            SplineCurve<V2>.ControlPoint(f($0.point), weight: $0.weight)
        })
    }
}

extension SplineCurve: ParametricCurve {
    /// Returns points sampled along a parameter subrange.
    ///
    /// - Parameters:
    ///   - range: The parameter range to sample within.
    ///   - segmentation: The sampling strategy. For `.fixed`, samples uniformly in parameter space.
    ///     For `.adaptive`, places points where the curve turns, following the segmentation's minimum angle and size.
    /// - Returns: An array of points covering the specified range.
    ///
    public func points(in range: ClosedRange<Double>, segmentation: Segmentation) -> [V] {
        let span = range.clamped(to: domain)

        switch segmentation {
        case .fixed(let n):
            let n = max(1, n)
            return (0...n).map { i in
                point(at: span.lowerBound + span.length * Double(i) / Double(n))
            }

        case .adaptive(let minAngle, let minSize):
            return adaptiveParameterSamples(in: span, minAngle: minAngle, minSize: minSize).map { point(at: $0) }
        }
    }


    /// Always returns `false` since a spline curve requires at least one control point.
    public var isEmpty: Bool { false }

    public var sampleCountForLengthApproximation: Int { controlPoints.count * 3 }

    /// The parameter range over which the curve is defined.
    public var domain: ClosedRange<Double> {
        knots[degree]...knots[knots.count - degree - 1]
    }

    public var derivativeView: any CurveDerivativeView<V> {
        SplineCurveDerivativeView(splineCurve: self)
    }

    /// Creates a 2D curve by transforming each control point.
    ///
    /// - Parameter transformer: A closure that converts each point to 2D.
    /// - Returns: A new 2D spline curve with transformed points.
    ///
    public func mapPoints(_ transformer: (V) -> Vector2D) -> SplineCurve<Vector2D> {
        map(transformer)
    }

    /// Creates a 3D curve by transforming each control point.
    ///
    /// - Parameter transformer: A closure that converts each point to 3D.
    /// - Returns: A new 3D spline curve with transformed points.
    ///
    public func mapPoints(_ transformer: (V) -> Vector3D) -> SplineCurve<Vector3D> {
        map(transformer)
    }

    public var labeledControlPoints: [(V, label: String?)]? {
        controlPoints.enumerated().map { controlPointIndex, controlPoint in
            if controlPoint.weight - 1.0 > .ulpOfOne {
                (controlPoint.point, String(format: "%d (%g)", controlPointIndex, controlPoint.weight))
            } else {
                (controlPoint.point, "\(controlPointIndex)")
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

extension SplineCurve: ParametricCurveBreakpoints {
    // The distinct knots, where one polynomial span hands over to the next. A repeated knot can leave a corner.
    var breakpoints: [Double] {
        Array(Set(knots)).sorted()
    }
}
