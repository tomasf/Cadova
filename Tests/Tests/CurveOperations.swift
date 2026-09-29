import Testing
import Foundation
@testable import Cadova

/// Operations every `ParametricCurve` gets from the protocol extensions.
struct CurveOperationTests {
    private static let bezierCircle = BezierPath2D(startPoint: [10, 0])
        .addingArc(center: .zero, to: 360°)

    private static let splineCircle: SplineCurve<Vector2D> = {
        let w = sqrt(0.5)
        return SplineCurve(
            degree: 2,
            knots: [0, 0, 0, 0.25, 0.25, 0.5, 0.5, 0.75, 0.75, 1, 1, 1],
            controlPoints: [
                ([10, 0], weight: 1), ([10, 10], weight: w),
                ([0, 10], weight: 1), ([-10, 10], weight: w),
                ([-10, 0], weight: 1), ([-10, -10], weight: w),
                ([0, -10], weight: 1), ([10, -10], weight: w),
                ([10, 0], weight: 1)
            ]
        )
    }()

    @Test func `approximate length is close to the true length`() {
        let circumference = 20 * Double.pi
        #expect(Self.bezierCircle.approximateLength.equals(circumference, within: circumference * 0.01))
        #expect(Self.splineCircle.approximateLength.equals(circumference, within: circumference * 0.01))

        let polyline = InterpolatingCurve<Vector2D>(through: [[0, 0], [5, 0], [10, 0], [15, 0]])
        #expect(polyline.approximateLength ≈ 15)
    }

    @Test func `approximate length never exceeds the finely measured length`() {
        // Any inscribed polyline is shorter than the curve, so a coarser measurement can only undershoot.
        let curve = InterpolatingCurve<Vector2D>(through: [[0, 0], [4, 9], [11, 2], [16, 12]])
        #expect(curve.approximateLength <= curve.length(segmentation: .fixed(2000)))
    }

    @Test func `2D curves lift into the XY plane in 3D`() {
        let lifted = Self.splineCircle.curve3D
        for u in stride(from: 0.0, through: 1.0, by: 0.05) {
            let flat = Self.splineCircle.point(at: u)
            #expect(lifted.point(at: u) ≈ Vector3D(flat.x, flat.y, 0))
        }
    }

    @Test func `3D curves are unchanged by curve3D`() {
        let curve = BezierPath3D(startPoint: [0, 0, 0])
            .addingCubicCurve(controlPoint1: [3, 5, 9], controlPoint2: [8, -2, 4], end: [10, 10, 10])
        let converted = curve.curve3D
        for u in stride(from: 0.0, through: 1.0, by: 0.1) {
            #expect(converted.point(at: u) ≈ curve.point(at: u))
        }
    }

    @Test func `reading points passes the sampled outline to the builder`() async throws {
        let polygon: any Geometry2D = Self.bezierCircle.readingPoints { points in
            Polygon(points)
        }
        let area = try await polygon.measurements.area
        #expect(area.equals(100 * .pi, within: 1))
    }

    @Test func `reading samples at a count places that many samples along the curve`() async throws {
        let line = BezierPath2D(linesBetween: [[0, 0], [30, 0]])
        let dots: any Geometry2D = line.readingSamples(at: .count(4)) { samples in
            for sample in samples {
                Rectangle(2).aligned(at: .center).translated(sample.position)
            }
        }
        let measurements = try await dots.measurements
        let area = await measurements.area
        #expect(area ≈ 16)
        #expect(measurements.boundingBox ≈ .init(minimum: [-1, -1], maximum: [31, 1]))
    }

    @Test func `reading transforms places frames at both ends of the curve`() async throws {
        let path = BezierPath3D(linesBetween: [[0, 0, 0], [30, 0, 0]])
        let markers: any Geometry3D = path.readingTransforms { transforms in
            for transform in [transforms.first!, transforms.last!] {
                Box(2).aligned(at: .center).transformed(transform)
            }
        }
        let measurements = try await markers.measurements
        let volume = await measurements.volume
        #expect(volume ≈ 16)
        #expect(measurements.boundingBox ≈ .init(minimum: [-1, -1, -1], maximum: [31, 1, 1]))
    }
}
