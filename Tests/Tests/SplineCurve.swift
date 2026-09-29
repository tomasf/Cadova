import Testing
import Foundation
@testable import Cadova

struct SplineCurveTests {
    /// A rational quadratic quarter circle of radius 1 from +X to +Y. The middle weight of cos(45°) makes it exact.
    private static let quarterCircle = SplineCurve<Vector2D>(
        degree: 2,
        knots: [0, 0, 0, 1, 1, 1],
        controlPoints: [([1, 0], weight: 1), ([1, 1], weight: sqrt(0.5)), ([0, 1], weight: 1)]
    )

    /// A full circle of radius 1 as four rational quadratic quarters joined by double knots.
    private static let fullCircle: SplineCurve<Vector2D> = {
        let w = sqrt(0.5)
        return SplineCurve(
            degree: 2,
            knots: [0, 0, 0, 0.25, 0.25, 0.5, 0.5, 0.75, 0.75, 1, 1, 1],
            controlPoints: [
                ([1, 0], weight: 1), ([1, 1], weight: w),
                ([0, 1], weight: 1), ([-1, 1], weight: w),
                ([-1, 0], weight: 1), ([-1, -1], weight: w),
                ([0, -1], weight: 1), ([1, -1], weight: w),
                ([1, 0], weight: 1)
            ]
        )
    }()

    /// An irregular cubic with nonuniform knots and weights, so symmetry can't hide a mistake.
    private static let irregularCubic = SplineCurve<Vector2D>(
        degree: 3,
        knots: [0, 0, 0, 0, 0.2, 0.7, 1, 1, 1, 1],
        controlPoints: [
            ([0, 0], weight: 1), ([2, 5], weight: 2.5), ([6, -1], weight: 0.7),
            ([9, 4], weight: 1.3), ([12, 0], weight: 1), ([15, 3], weight: 1)
        ]
    )

    private static let parameters = (0...20).map { Double($0) / 20 }

    @Test func `weighted quadratic quarter circle stays on the circle`() {
        for u in Self.parameters {
            #expect(Self.quarterCircle.point(at: u).magnitude ≈ 1)
        }
        #expect(Self.quarterCircle.point(at: 0) ≈ [1, 0])
        #expect(Self.quarterCircle.point(at: 1) ≈ [0, 1])
    }

    @Test func `full circle with repeated interior knots stays on the circle`() {
        for u in Self.parameters {
            #expect(Self.fullCircle.point(at: u).magnitude ≈ 1)
        }
        // Double knots make each quarter interpolate its end point.
        #expect(Self.fullCircle.point(at: 0.25) ≈ [0, 1])
        #expect(Self.fullCircle.point(at: 0.5) ≈ [-1, 0])
        #expect(Self.fullCircle.point(at: 0.75) ≈ [0, -1])
        #expect(Self.fullCircle.isClosed)
    }

    @Test func `circle length matches its circumference`() {
        #expect(Self.fullCircle.length(segmentation: .fixed(2000)).equals(2 * .pi, within: 1e-4))
    }

    @Test func `unweighted single span spline matches the Bezier curve with the same control points`() {
        let controlPoints: [Vector3D] = [[0, 0, 0], [3, 8, 1], [7, -2, 4], [10, 3, 0]]
        let spline = SplineCurve<Vector3D>(
            degree: 3,
            knots: [0, 0, 0, 0, 1, 1, 1, 1],
            controlPoints: controlPoints.map { ($0, weight: 1) }
        )
        let bezier = BezierCurve(controlPoints: controlPoints)

        for u in Self.parameters {
            #expect(spline.point(at: u) ≈ bezier.point(at: u))
        }
    }

    @Test func `degree one spline is the polyline through its control points`() {
        let spline = SplineCurve<Vector2D>.uniformClamped(degree: 1, controlPoints: [[0, 0], [10, 0], [10, 20]])

        #expect(spline.domain == 0...1)
        #expect(spline.point(at: 0.25) ≈ [5, 0])
        #expect(spline.point(at: 0.5) ≈ [10, 0])
        #expect(spline.point(at: 0.75) ≈ [10, 10])
    }

    @Test func `uniform clamped splines interpolate their end points`() {
        let controlPoints: [Vector2D] = [[0, 0], [4, 9], [8, -3], [13, 6], [17, 1]]
        for spline in [SplineCurve.uniformQuadratic(controlPoints: controlPoints), .uniformCubic(controlPoints: controlPoints)] {
            #expect(spline.domain == 0...1)
            #expect(spline.point(at: 0) ≈ controlPoints.first!)
            #expect(spline.point(at: 1) ≈ controlPoints.last!)
        }
    }

    @Test func `uniform cubic spline end tangents follow the control polygon`() {
        let spline = SplineCurve<Vector2D>.uniformCubic(controlPoints: [[0, 0], [0, 10], [10, 10], [20, 10], [20, 0]])
        #expect(spline.tangent(at: 0).unitVector ≈ [0, 1])
        #expect(spline.tangent(at: 1).unitVector ≈ [0, -1])
    }

    @Test func `raising a weight pulls the curve toward its control point by the rational amount`() {
        let spline = SplineCurve<Vector2D>.uniformQuadratic(controlPoints: [[0, 0], [1, 2], [2, 0]])
        #expect(spline.point(at: 0.5) ≈ [1, 1])

        // At the midpoint of a rational quadratic, y = 2w / (1 + w) for a middle weight w.
        let weighted = spline.withWeight(3, forControlPointAtIndex: 1)
        #expect(weighted.point(at: 0.5) ≈ [1, 1.5])
        #expect(weighted.point(at: 0) ≈ [0, 0])
        #expect(weighted.point(at: 1) ≈ [2, 0])
    }

    @Test func `reversed spline traces the same points backwards`() {
        let reversed = Self.irregularCubic.reversed()
        #expect(reversed.domain == Self.irregularCubic.domain)
        for u in Self.parameters {
            #expect(reversed.point(at: u) ≈ Self.irregularCubic.point(at: 1 - u))
        }
        #expect(reversed.reversed().points(segmentation: .fixed(20)) ≈ Self.irregularCubic.points(segmentation: .fixed(20)))
    }

    @Test func `transforming a spline transforms its points`() {
        let transform = Transform2D.rotation(37°).translated(x: 4, y: -9)
        let transformed = Self.irregularCubic.transformed(transform)
        for u in Self.parameters {
            #expect(transformed.point(at: u) ≈ transform.apply(to: Self.irregularCubic.point(at: u)))
        }
    }

    @Test func `mapping a spline to 3D keeps its points and weights`() {
        let lifted = Self.quarterCircle.mapPoints { Vector3D($0.x, $0.y, 5) }
        for u in Self.parameters {
            let point = lifted.point(at: u)
            #expect(point.z ≈ 5)
            #expect(Vector2D(point.x, point.y).magnitude ≈ 1)
        }
    }

    @Test func `sampling a parameter range starts and ends at the range bounds`() {
        let points = Self.irregularCubic.points(in: 0.3...0.8, segmentation: .fixed(7))
        #expect(points.count == 8)
        #expect(points.first! ≈ Self.irregularCubic.point(at: 0.3))
        #expect(points.last! ≈ Self.irregularCubic.point(at: 0.8))
    }

    @Test func `adaptive sampling keeps every segment below the requested size`() {
        let points = Self.fullCircle.points(segmentation: .adaptive(minAngle: 5°, minSize: 0.2))
        #expect(points.first! ≈ [1, 0])
        #expect(points.last! ≈ [1, 0])
        for (a, b) in points.paired() {
            #expect(a.distance(to: b) < 0.2)
            #expect(a.magnitude ≈ 1)
        }
    }
}
