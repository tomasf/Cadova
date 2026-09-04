import Testing
import Foundation
@testable import Cadova

/// Regressions for degenerate curve inputs: frame runs with no resolvable twist angle, collapsed
/// parameter ranges, and curves whose tangent vanishes where control points coincide.
struct CurveDegenerateInputTests {

    // MARK: - Frame angle interpolation

    /// A frame carrying only the fields `interpolateMissingAngles()` reads.
    private static func frame(t: Double, angle: Angle?) -> ParametricCurveFrame {
        ParametricCurveFrame(
            t: t,
            distance: t,
            point: Vector3D(t, 0, 0),
            xAxis: Vector3D(0, 1, 0),
            yAxis: Vector3D(0, 0, 1),
            zAxis: Vector3D(1, 0, 0),
            angle: angle,
            miterStretch: nil
        )
    }

    private static func interpolatedAngles(_ angles: [Angle?]) -> [Angle] {
        var frames = angles.enumerated().map { frame(t: Double($0.offset), angle: $0.element) }
        frames.interpolateMissingAngles()
        return frames.map { $0.angle! }
    }

    @Test func `missing frame angles are spaced evenly strictly between the bounding known angles`() {
        #expect(Self.interpolatedAngles([0°, nil, nil, nil, 40°]) ≈ [0°, 10°, 20°, 30°, 40°])
    }

    @Test func `a single missing frame angle lands halfway between its neighbours`() {
        #expect(Self.interpolatedAngles([20°, nil, 50°]) ≈ [20°, 35°, 50°])
    }

    @Test func `missing frame angles take the short way around the plus minus 180 degree seam`() {
        // 170° → -170° is a +20° step the short way round; the long way would unwind 340°.
        #expect(Self.interpolatedAngles([170°, nil, -170°]) ≈ [170°, 180°, -170°])
    }

    @Test func `a descending run of missing frame angles interpolates downwards`() {
        // A descending pair used to build an inverted Range<Angle> and trap.
        #expect(Self.interpolatedAngles([90°, nil, nil, 0°]) ≈ [90°, 60°, 30°, 0°])
    }

    @Test func `a missing run at the start of the sequence adopts the first known angle`() {
        #expect(Self.interpolatedAngles([nil, nil, 30°, 60°]) ≈ [30°, 30°, 30°, 60°])
    }

    @Test func `a missing run at the end of the sequence keeps the last known angle`() {
        #expect(Self.interpolatedAngles([30°, 60°, nil, nil]) ≈ [30°, 60°, 60°, 60°])
    }

    @Test func `a sequence with no known angles resolves to zero`() {
        #expect(Self.interpolatedAngles([nil, nil, nil]) ≈ [0°, 0°, 0°])
    }

    @Test func `several separate missing runs are each interpolated`() {
        #expect(Self.interpolatedAngles([0°, nil, 20°, nil, 40°]) ≈ [0°, 10°, 20°, 30°, 40°])
    }

    // MARK: - Collapsed parameter ranges

    private static var twoCurvePath: BezierPath2D {
        BezierPath2D(startPoint: [0, 0])
            .addingCubicCurve(controlPoint1: [0, 10], controlPoint2: [10, 10], end: [10, 0])
            .addingLine(to: [20, 0])
    }

    @Test func `sampling a collapsed range at a curve boundary yields that single point`() {
        // (1...1) used to pull upperIndex below lowerIndex and trap on an inverted Int range.
        #expect(Self.twoCurvePath.points(in: 1...1, segmentation: .fixed(4)) ≈ [[10, 0]])
    }

    @Test func `sampling a collapsed range inside a curve yields that single point`() {
        // This used to fabricate a one-control-point curve, which points() then indexed out of range.
        let path = Self.twoCurvePath
        #expect(path.points(in: 0.5...0.5, segmentation: .fixed(4)) ≈ [path.point(at: 0.5)])
    }

    @Test func `sampling a collapsed range at the end of the path yields that single point`() {
        #expect(Self.twoCurvePath.points(in: 2...2, segmentation: .fixed(4)) ≈ [[20, 0]])
    }

    @Test func `a subcurve collapsed onto a point is not sampled as a line`() {
        let curve = BezierPath2D.Curve(controlPoints: [[0, 0], [10, 0]]).subcurve(in: 0.25...0.25)
        #expect(curve.controlPoints.count == 1)
        let points = curve.points(segmentation: .fixed(4), subdividingStraightLines: false).map(\.1)
        #expect(points ≈ [[2.5, 0], [2.5, 0]])
    }

    @Test func `sampling ordinary subranges is unaffected`() {
        #expect(Self.twoCurvePath.points(in: 0...1, segmentation: .fixed(2)) ≈ [[0, 0], [5, 7.5], [10, 0]])
        // The second curve is a straight line, which points() deliberately does not subdivide.
        #expect(Self.twoCurvePath.points(in: 1...2, segmentation: .fixed(2)) ≈ [[10, 0], [20, 0]])
        #expect(Self.twoCurvePath.points(in: 0.5...1.5, segmentation: .fixed(2)) ≈ [[5, 7.5], [8.4375, 5.625], [10, 0], [15, 0]])
    }

    // MARK: - Vanishing tangents

    @Test func `a cubic leaving its start point with no tension has a unit tangent`() {
        // P0 == P1, so B'(0) is exactly zero; the true tangent comes from B''(0).
        let curve = BezierPath2D.Curve(controlPoints: [[0, 0], [0, 0], [10, 0], [10, 10]])
        let tangent = curve.tangent(at: 0)
        #expect(tangent.unitVector.magnitude ≈ 1)
        #expect(tangent ≈ Direction2D(x: 1, y: 0))
    }

    @Test func `a cubic reaching its end point with no tension has a unit tangent`() {
        // P2 == P3, so B'(1) is exactly zero. B''(1) points backwards along the travel direction here,
        // since the end can only be approached from inside the curve.
        let curve = BezierPath2D.Curve(controlPoints: [[0, 0], [0, 10], [10, 10], [10, 10]])
        let tangent = curve.tangent(at: 1)
        #expect(tangent.unitVector.magnitude ≈ 1)
        #expect(tangent ≈ Direction2D(x: 1, y: 0))
    }

    @Test func `a 3D cubic with a coincident start pair has a unit tangent`() {
        let curve = BezierPath3D.Curve(controlPoints: [[0, 0, 0], [0, 0, 0], [0, 0, 10], [5, 0, 10]])
        let tangent = curve.tangent(at: 0)
        #expect(tangent.unitVector.magnitude ≈ 1)
        #expect(tangent ≈ Direction3D(x: 0, y: 0, z: 1))
    }

    @Test func `an undefined direction is exactly the zero direction`() {
        #expect(Direction3D.undefined.isUndefined)
        #expect(Direction3D(Vector3D.zero).isUndefined)
        #expect(Direction3D(Vector3D.zero) == .undefined)
        #expect(Direction2D.undefined.isUndefined)

        // A vector of any usable length normalizes to unit length, however small.
        let small = Direction3D(Vector3D(1e-100, 0, 0))
        #expect(small.isUndefined == false)
        #expect(small.unitVector.magnitude ≈ 1)

        // An ordinary direction is defined.
        #expect(Direction3D(Vector3D(0, 0, 5)).isUndefined == false)
    }

    @Test func `a line collapsed to a point has no direction to report`() {
        // Nothing here is a tangent: the curve never moves. This documents that the degenerate case is
        // left as it has always been rather than being given an arbitrary direction that would be
        // indistinguishable from a real one.
        let curve = BezierPath2D.Curve(controlPoints: [[3, 4], [3, 4]])
        #expect(curve.tangent(at: 0.5).isUndefined)
    }

    @Test func `a path end direction is unit length when the last curve has no end tension`() {
        let path = BezierPath2D(startPoint: [0, 0])
            .addingCubicCurve(controlPoint1: [0, 10], controlPoint2: [10, 10], end: [10, 10])
        let direction = try! #require(path.endDirection)
        #expect(direction.unitVector.magnitude ≈ 1)
        #expect(direction ≈ Direction2D(x: 1, y: 0))
    }

    @Test func `a path derivative view reports a unit tangent at a coincident control point`() {
        let path = BezierPath2D(startPoint: [0, 0])
            .addingCubicCurve(controlPoint1: [0, 0], controlPoint2: [10, 0], end: [10, 10])
        let tangent = path.derivativeView.tangent(at: 0)
        #expect(tangent.unitVector.magnitude ≈ 1)
        #expect(tangent ≈ Direction2D(x: 1, y: 0))
    }

    @Test func `ordinary bezier tangents are unchanged`() {
        let curve = BezierPath2D.Curve(controlPoints: [[0, 0], [0, 10], [10, 10], [10, 0]])
        #expect(curve.tangent(at: 0) ≈ Direction2D(x: 0, y: 1))
        #expect(curve.tangent(at: 1) ≈ Direction2D(x: 0, y: -1))
        #expect(curve.tangent(at: 0.5) ≈ Direction2D(x: 1, y: 0))
    }

    @Test func `an interpolating curve with a repeated point stays finite`() {
        // Coincident points make the centripetal times zero, and the reciprocal of the subnormal floor
        // guarding that division used to overflow to infinity, turning every point on the segment NaN.
        let curve = InterpolatingCurve<Vector2D>(through: [[0, 0], [0, 0], [10, 0]])
        let points = curve.points(segmentation: .fixed(8))
        #expect(points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        #expect(points.first ≈ [0, 0])
        #expect(points.last ≈ [10, 0])
    }

    @Test func `an interpolating curve stalled by a repeated point still has a unit tangent`() {
        // The first two points coincide, so the whole first segment collapses to a single point and a
        // finite difference across it is exactly zero.
        let curve = InterpolatingCurve<Vector2D>(through: [[0, 0], [0, 0], [10, 0]])
        let tangent = curve.derivativeView.tangent(at: 0)
        #expect(tangent.unitVector.magnitude ≈ 1)
        #expect(tangent ≈ Direction2D(x: 1, y: 0))
    }

    @Test func `ordinary interpolating curve tangents are unchanged`() {
        let curve = InterpolatingCurve<Vector2D>(through: [[0, 0], [10, 0], [20, 0]])
        #expect(curve.derivativeView.tangent(at: 1) ≈ Direction2D(x: 1, y: 0))
    }

    @Test func `a spline curve stalled by repeated control points still has a unit tangent`() {
        // The first three control points coincide, so the curve is stationary across the whole first
        // knot span and a finite difference there is exactly zero.
        let curve = SplineCurve<Vector2D>(
            degree: 2,
            knots: [0, 0, 0, 1, 2, 2, 2],
            controlPoints: [([0, 0], weight: 1), ([0, 0], weight: 1), ([0, 0], weight: 1), ([10, 0], weight: 1)]
        )
        for u in [0.0, 0.25, 0.5] {
            let tangent = curve.tangent(at: u)
            #expect(tangent.unitVector.magnitude ≈ 1, "at u = \(u)")
            #expect(tangent ≈ Direction2D(x: 1, y: 0), "at u = \(u)")
        }
    }

    @Test func `ordinary spline tangents are unchanged`() {
        let curve = SplineCurve<Vector2D>(
            degree: 2,
            knots: [0, 0, 0, 1, 1, 1],
            controlPoints: [([0, 0], weight: 1), ([10, 0], weight: 1), ([10, 10], weight: 1)]
        )
        #expect(curve.tangent(at: 0) ≈ Direction2D(x: 1, y: 0))
        #expect(curve.tangent(at: 1) ≈ Direction2D(x: 0, y: 1))
    }
}
