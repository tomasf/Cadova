import Testing
import Foundation
@testable import Cadova

struct InterpolatingCurveTests {
    private static let openPoints: [Vector2D] = [[0, 0], [3, 7], [9, 8], [12, 1], [20, 4]]
    private static let openCurve = InterpolatingCurve(through: openPoints)

    private static let closedPoints: [Vector2D] = [[0, 0], [10, 0], [12, 8], [4, 11], [0, 0]]
    private static let closedCurve = InterpolatingCurve(through: closedPoints)

    @Test func `curve passes through every point it was given`() {
        #expect(Self.openCurve.domain == 0...4)
        for (index, point) in Self.openPoints.enumerated() {
            #expect(Self.openCurve.point(at: Double(index)) ≈ point)
        }
    }

    @Test func `3D curve passes through every point it was given`() {
        let points: [Vector3D] = [[0, 0, 0], [5, 2, 8], [1, 9, 3], [7, 7, 7]]
        let curve = InterpolatingCurve(through: points)
        for (index, point) in points.enumerated() {
            #expect(curve.point(at: Double(index)) ≈ point)
        }
    }

    @Test func `sampling includes every point it was given`() {
        let samples = Self.openCurve.points(segmentation: .fixed(40))
        for point in Self.openPoints {
            let isSampled = samples.contains { $0 ≈ point }
            #expect(isSampled)
        }
    }

    @Test func `parameters outside the domain are clamped to the ends`() {
        #expect(Self.openCurve.point(at: -3) ≈ Self.openPoints.first!)
        #expect(Self.openCurve.point(at: 12) ≈ Self.openPoints.last!)
    }

    @Test func `evenly spaced collinear points give a straight line`() {
        let curve = InterpolatingCurve<Vector2D>(through: [[0, 0], [2, 1], [4, 2], [6, 3]])
        for point in curve.points(segmentation: .fixed(30)) {
            let expectedY = point.x / 2
            #expect(point.y ≈ expectedY)
        }
        #expect(curve.length(segmentation: .fixed(30)) ≈ Vector2D(6, 3).magnitude)
    }

    @Test func `a curve returning to its first point is closed`() {
        #expect(Self.closedCurve.isClosed)
        #expect(Self.openCurve.isClosed == false)
    }

    @Test func `a closed curve has no cusp at its seam`() {
        let start = Self.closedCurve.tangent(at: Self.closedCurve.domain.lowerBound)
        let end = Self.closedCurve.tangent(at: Self.closedCurve.domain.upperBound)
        #expect(start.unitVector ≈ end.unitVector)
    }

    @Test func `an open curve does not wrap its end tangents`() {
        // Open ends extrapolate the neighbouring segment rather than borrowing from the far end.
        let curve = InterpolatingCurve<Vector2D>(through: [[0, 0], [10, 0], [10, 10], [0, 10]])
        #expect(curve.tangent(at: 0).unitVector ≈ [1, 0])
        #expect(curve.tangent(at: 3).unitVector ≈ [-1, 0])
    }

    @Test func `sampling a parameter range starts and ends at the range bounds`() {
        let points = Self.openCurve.points(in: 0.5...2.75, segmentation: .fixed(9))
        #expect(points.count == 10)
        #expect(points.first! ≈ Self.openCurve.point(at: 0.5))
        #expect(points.last! ≈ Self.openCurve.point(at: 2.75))
    }

    @Test func `adaptive sampling keeps every segment below the requested size`() {
        let points = Self.openCurve.points(segmentation: .adaptive(minAngle: 5°, minSize: 0.5))
        #expect(points.first! ≈ Self.openPoints.first!)
        #expect(points.last! ≈ Self.openPoints.last!)
        for (a, b) in points.paired() {
            #expect(a.distance(to: b) < 0.5)
        }
    }

    @Test func `transforming a curve transforms its points`() {
        let transform = Transform2D.rotation(-52°).translated(x: 11, y: 3)
        let transformed = Self.openCurve.transformed(transform)
        for u in stride(from: 0.0, through: 4.0, by: 0.2) {
            #expect(transformed.point(at: u) ≈ transform.apply(to: Self.openCurve.point(at: u)))
        }
    }

    @Test func `mapping a curve to 3D keeps its shape`() {
        let lifted = Self.openCurve.mapPoints { Vector3D($0.x, $0.y, -2) }
        for u in stride(from: 0.0, through: 4.0, by: 0.2) {
            let flat = Self.openCurve.point(at: u)
            #expect(lifted.point(at: u) ≈ Vector3D(flat.x, flat.y, -2))
        }
    }
}
