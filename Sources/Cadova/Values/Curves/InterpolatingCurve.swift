import Foundation

/// Interpolating curves are Catmull–Rom splines that interpolate their control points
/// using centripetal parameterization.
///
/// Catmull–Rom splines are cubic, piecewise curves defined by a sequence of points the curve passes through.
/// The curve auto-detects closure: if the first and last points coincide, it behaves as a closed curve,
/// ensuring a smooth seam without a cusp.
///
public struct InterpolatingCurve<V: Vector>: ParametricCurve, Sendable, Hashable, Codable {
    let points: [V]

    /// Creates an interpolating (centripetal Catmull–Rom) curve through `points`.
    ///
    /// - Parameters:
    ///   - points: Control points the curve interpolates. Must contain at least two points.
    public init(through points: [V]) {
        precondition(points.count >= 2, "Interpolating curve requires at least two points")
        self.points = points
    }

    private var isClosed: Bool {
        points.first!.distance(to: points.last!) < 1e-6
    }

    /// Number of distinct support points used for wrapping at the seam.
    private var wrappedSupportCount: Int { isClosed ? (points.count - 1) : points.count }

    public var isEmpty: Bool { false }

    /// Domain measured in segment units (e.g. `1.25` is 25% into the second segment).
    public var domain: ClosedRange<Double> {
        0 ... Double(points.count - 1)
    }

    public var sampleCountForLengthApproximation: Int { (points.count - 1) * 4 }

    public func point(at u: Double) -> V {
        let uClamped = u.clamped(to: domain)
        let segmentIndex = min(Int(floor(uClamped)), max(points.count - 2, 0))
        let localFraction = uClamped - Double(segmentIndex)

        let p0 = controlPoint(atWrapped: segmentIndex - 1)
        let p1 = controlPoint(atWrapped: segmentIndex + 0)
        let p2 = controlPoint(atWrapped: segmentIndex + 1)
        let p3 = controlPoint(atWrapped: segmentIndex + 2)

        @inline(__always)
        func dt(_ a: V, _ b: V) -> Double {
            sqrt((b - a).magnitude) // pow(||b-a||, 0.5)
        }

        let t1 = dt(p0, p1)
        let t2 = t1 + dt(p1, p2)
        let t3 = t2 + dt(p2, p3)
        let t = t1 + localFraction * (t2 - t1)

        // Tangents (general CR with centripetal times)
        let m1 = (p2 - p0) * (1.0 / max(t2, .leastNonzeroMagnitude))
        let m2 = (p3 - p1) * (1.0 / max(t3 - t1, .leastNonzeroMagnitude))

        // Cubic Hermite basis over s in [0,1]
        let s = (t - t1) / max(t2 - t1, .leastNonzeroMagnitude)
        let s2 = s * s
        let s3 = s2 * s
        let h00 = 2*s3 - 3*s2 + 1
        let h10 = s3 - 2*s2 + s
        let h01 = -2*s3 + 3*s2
        let h11 = s3 - s2

        return p1 * h00
        + m1 * ((t2 - t1) * h10)
        + p2 * h01
        + m2 * ((t2 - t1) * h11)
    }

    // MARK: - Sampling

    public func points(segmentation: Segmentation) -> [V] {
        points(in: domain, segmentation: segmentation)
    }

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

    @inline(__always)
    private func controlPoint(atWrapped i: Int) -> V {
        if isClosed {
            return points[((i % wrappedSupportCount) + wrappedSupportCount) % wrappedSupportCount]
        }
        if i < 0 {
            let p0 = points[0]
            let p1 = points[min(1, points.count - 1)]
            return p0 + (p0 - p1)
        } else if i >= points.count {
            let pnm1 = points[points.count - 1]
            let pnm2 = points[max(points.count - 2, 0)]
            return pnm1 + (pnm1 - pnm2)
        } else {
            return points[i]
        }
    }

    public var derivativeView: any CurveDerivativeView<V> {
        InterpolatingCurveDerivativeView(curve: self)
    }

    public func mapPoints(_ transformer: (V) -> Vector2D) -> InterpolatingCurve<Vector2D> {
        InterpolatingCurve<Vector2D>(through: points.map(transformer))
    }

    public func mapPoints(_ transformer: (V) -> Vector3D) -> InterpolatingCurve<Vector3D> {
        InterpolatingCurve<Vector3D>(through: points.map(transformer))
    }

    public var labeledControlPoints: [(V, label: String?)]? {
        let wrapAroundIndex = isClosed ? points.count - 1 : -1
        return points.enumerated().map {
            ($0.element, $0.offset == wrapAroundIndex ? nil : "\($0.offset)")
        }
    }
}

// MARK: - Derivative view

internal struct InterpolatingCurveDerivativeView<V: Vector>: CurveDerivativeView {
    let curve: InterpolatingCurve<V>

    func tangent(at u: Double) -> Direction<V.D> {
        let eps = max(1e-6, 1e-6 * curve.domain.length)
        let a = curve.point(at: (u - eps).clamped(to: curve.domain))
        let b = curve.point(at: (u + eps).clamped(to: curve.domain))
        return Direction(b - a)
    }
}
