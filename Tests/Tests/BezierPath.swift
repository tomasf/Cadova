import Testing
import Foundation
@testable import Cadova

struct BezierPathTests {
    let linearPoints: [Vector3D] = [[56.2, 64, 2], [25.1, 34, 100], [0, -24, 55]]
    let linearPath: BezierPath3D

    let quadraticPath = BezierPath2D(startPoint: [39.1, 150])
        .addingQuadraticCurve(controlPoint: [20.1, 55], end: [0, 500])
        .addingCurve([320, 82.3], [393, 0])

    init() {
        linearPath = BezierPath3D(linesBetween: linearPoints)
    }

    @Test func `quadratic path with fixed segmentation produces correct points`() {
        let points = quadraticPath.points(segmentation: .fixed(5))
        #expect(points ≈ [[39.1, 150], [31.456, 133.6], [23.724, 160.4], [15.904, 230.4], [7.996, 343.6], [0, 500], [118.12, 346.336], [216.48, 219.504], [295.08, 119.504], [353.92, 46.336], [393, 0]])
    }

    @Test func `quadratic path with adaptive segmentation produces correct points`() {
        let points = quadraticPath.points(segmentation: .adaptive(minAngle: 10°, minSize: 20))

        // Each curve is split only while a piece is both longer than 20 and turns by more than 10°. The second one
        // turns by only about 4° from end to end, so it stays a single segment.
        #expect(points ≈ [[39.1, 150.0], [37.097, 141.4958], [35.0878, 135.9834], [33.0726, 133.4626], [31.0512, 133.9335], [29.0238, 137.3961], [26.9903, 143.8504], [24.9507, 153.2964], [22.905, 165.7341], [20.8532, 181.1634], [18.7953, 199.5845], [16.7313, 220.9972], [14.6612, 245.4017], [12.585, 272.7978], [10.5028, 303.1856], [8.4144, 336.5651], [6.3199, 372.9363], [4.2194, 412.2992], [2.1127, 454.6537], [0.0, 500.0], [393.0, 0.0]])
    }

    @Test func `circular arc produces correct control points and area`() async throws {
        let path = BezierPath2D(startPoint: [10, 0])
            .addingArc(center: .zero, to: 360°, clockwise: false)

        let controlPoints = path.curves.map(\.controlPoints)
        let expectedControlPoints: [[Vector2D]] = [
            [[10, 0],  [10, 5.52285],  [5.52285, 10],  [0, 10]],
            [[0, 10],  [-5.52285, 10],  [-10, 5.52285],  [-10, 0]],
            [[-10, 0],  [-10, -5.52285],  [-5.52285, -10],  [0, -10]],
            [[0, -10],  [5.52285, -10],  [10, -5.52285],  [10, 0]]
        ]
        #expect(controlPoints ≈ expectedControlPoints)

        let geometry = Polygon(path)
        let m = try await geometry.measurements
        let area = await m.area
        #expect(floor(area) ≈ 314)
    }

    @Test func `partial arc produces correct control points and bounds`() async throws {
        let path = BezierPath2D(startPoint: [10, 0])
            .addingArc(center: [1, 2], to: 100°, clockwise: false)

        let controlPoints = path.curves.map(\.controlPoints)
        let expectedControlPoints: [[Vector2D]] = [
            [[10, 0],  [10.6681, 3.00665],  [9.79076, 6.14835],  [7.66147, 8.37376]],
            [[7.66147, 8.37376],  [5.53218, 10.5992],  [2.43224, 11.6143],  [-0.600957, 11.0795]]
        ]
        #expect(controlPoints ≈ expectedControlPoints)

        // Sampled finely enough that the polygon's area and bounds match the arc's own. Its cubic curves bulge very
        // slightly past the true circle, whose segment would be 44.212.
        let m = try await Polygon(path).withSegmentation(minAngle: 0.1°, minSize: 0.001).measurements
        let area = await m.area

        #expect(area ≈ 44.215)
        #expect(m.boundingBox ≈ .init(minimum: [-0.601, 0], maximum: [10.220, 11.220]))
    }

    /// A cubic arc approximation deviates from the true radius by at most about 0.03%.
    private static func expectOnCircle(_ path: BezierPath2D, center: Vector2D, radius: Double) {
        for point in path.points(segmentation: .fixed(16)) {
            #expect(point.distance(to: center).equals(radius, within: radius * 3e-4))
        }
    }

    @Test func `clockwise arc sweeps the short way to its end angle`() {
        let path = BezierPath2D(startPoint: [10, 0])
            .addingArc(center: .zero, to: -90°, clockwise: true)

        #expect(path.curves.count == 1)
        #expect(path.point(at: 1) ≈ [0, -10])
        #expect(path.point(at: 0.5) ≈ [7.0711, -7.0711])
        Self.expectOnCircle(path, center: .zero, radius: 10)
    }

    @Test func `clockwise arc sweeps the long way when the end angle is behind it`() {
        let path = BezierPath2D(startPoint: [10, 0])
            .addingArc(center: .zero, to: 90°, clockwise: true)

        // 270° clockwise, split into segments of at most 90°.
        #expect(path.curves.count == 3)
        #expect(path.point(at: 1) ≈ [0, -10])
        #expect(path.point(at: 2) ≈ [-10, 0])
        #expect(path.point(at: 3) ≈ [0, 10])
        Self.expectOnCircle(path, center: .zero, radius: 10)
    }

    @Test func `arc splits its sweep into equal segments of at most 90 degrees`() {
        let path = BezierPath2D(startPoint: [5, 0])
            .addingArc(center: .zero, to: 200°)

        #expect(path.curves.count == 3)
        for (index, angle) in [0°, 200° / 3, 400° / 3, 200°].enumerated() {
            #expect(path.point(at: Double(index)) ≈ Vector2D(5 * cos(angle), 5 * sin(angle)))
        }
    }

    @Test func `arc takes its radius and start angle from the current point`() {
        let path = BezierPath2D(startPoint: [4, 7])
            .addingArc(center: [1, 3], to: 180°)

        #expect(path.point(at: path.domain.upperBound) ≈ [-4, 3])
        Self.expectOnCircle(path, center: [1, 3], radius: 5)
    }

    @Test func `arc leaves a tangent line smoothly`() {
        let path = BezierPath2D(startPoint: [0, 0])
            .addingLine(to: [10, 0])
            .addingArc(center: [10, 5], to: 90°)

        #expect(path.curves[1].tangent(at: 0).unitVector ≈ [1, 0])
        #expect(path.point(at: path.domain.upperBound) ≈ [10, 10])
        #expect(path.tangent(at: path.domain.upperBound).unitVector ≈ [-1, 0])
    }

    @Test func `arc from the center point is ignored`() {
        let path = BezierPath2D(startPoint: [3, 3])
            .addingArc(center: [3, 3], to: 90°)
        #expect(path.isEmpty)
    }

    @Test func `arc approximation length matches the circle`() {
        let path = BezierPath2D(startPoint: [10, 0])
            .addingArc(center: .zero, to: 360°)
        #expect(path.length(segmentation: .fixed(200)).equals(20 * .pi, within: 0.01))
    }
}
