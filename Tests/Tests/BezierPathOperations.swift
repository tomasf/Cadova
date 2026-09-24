import Testing
import Foundation
@testable import Cadova

struct BezierPathOperationTests {
    private static let path = BezierPath2D(startPoint: [0, 0])
        .addingLine(to: [10, 0])
        .addingQuadraticCurve(controlPoint: [18, 3], end: [15, 12])
        .addingCubicCurve(controlPoint1: [12, 20], controlPoint2: [2, 18], end: [-3, 9])

    private static let otherPath = BezierPath2D(startPoint: [-3, 9])
        .addingCubicCurve(controlPoint1: [-8, 0], controlPoint2: [-4, -6], end: [0, -8])
        .addingLine(to: [5, -8])

    private static let parameters = stride(from: 0.0, through: 3.0, by: 0.125)

    @Test func `reversed path traces the same points backwards`() {
        let reversed = Self.path.reversed()
        #expect(reversed.domain == Self.path.domain)
        #expect(reversed.points(segmentation: .fixed(8)) ≈ Array(Self.path.points(segmentation: .fixed(8)).reversed()))
        for u in Self.parameters {
            #expect(reversed.point(at: 3 - u) ≈ Self.path.point(at: u))
        }
    }

    @Test func `reversing a path twice gives back the original`() {
        #expect(Self.path.reversed().reversed() ≈ Self.path)
    }

    @Test func `appending a path that starts where this one ends joins them directly`() {
        let joined = Self.path.appending(Self.otherPath)
        #expect(joined.curves.count == Self.path.curves.count + Self.otherPath.curves.count)
        let expected = Self.path.points(segmentation: .fixed(8)) + Self.otherPath.points(segmentation: .fixed(8)).dropFirst()
        #expect(joined.points(segmentation: .fixed(8)) ≈ expected)
    }

    @Test func `appending a path that starts elsewhere bridges the gap with a line`() {
        let distant = Self.otherPath.transformed(.translation(x: 30))
        let joined = Self.path.appending(distant)

        #expect(joined.curves.count == Self.path.curves.count + 1 + distant.curves.count)
        let bridge = joined.curves[Self.path.curves.count]
        #expect(bridge.controlPoints ≈ [[-3, 9], [27, 9]])
        #expect(joined.point(at: joined.domain.upperBound) ≈ [35, -8])
    }

    @Test func `closing a path adds a line back to its start`() {
        let closed = Self.path.closed()
        #expect(closed.curves.count == Self.path.curves.count + 1)
        #expect(closed.curves.last!.controlPoints ≈ [[-3, 9], [0, 0]])
        #expect(closed.isClosed)
        #expect(Self.path.isClosed == false)
    }

    @Test func `path derivative matches the rate of change along the path`() {
        let derivative = Self.path.derivative
        let h = 1e-6
        for u in stride(from: 0.05, through: 2.95, by: 0.1) {
            let difference = (Self.path.point(at: u + h) - Self.path.point(at: u - h)) / (2 * h)
            #expect(derivative.point(at: u) ≈ difference)
        }
    }

    @Test func `subdivided points also split straight lines`() {
        let line = BezierPath2D(linesBetween: [[0, 0], [10, 0], [10, 10]])
        #expect(line.points(segmentation: .fixed(5)) ≈ [[0, 0], [10, 0], [10, 10]])
        #expect(line.subdividedPoints(segmentation: .fixed(5)) ≈ [
            [0, 0], [2, 0], [4, 0], [6, 0], [8, 0], [10, 0],
            [10, 2], [10, 4], [10, 6], [10, 8], [10, 10]
        ])
    }

    @Test func `transforming a path transforms its points`() {
        let transform = Transform2D.rotation(71°).translated(x: -6, y: 14)
        let transformed = Self.path.transformed(transform)
        for u in Self.parameters {
            #expect(transformed.point(at: u) ≈ transform.apply(to: Self.path.point(at: u)))
        }
    }

    @Test func `mapping a path to 3D maps every control point`() {
        let lifted = Self.path.mapPoints { Vector3D($0.x, $0.y, $0.x * 0.5) }
        for u in Self.parameters {
            let flat = Self.path.point(at: u)
            // An affine map commutes with Bezier evaluation, so the lifted path is the lifted points.
            #expect(lifted.point(at: u) ≈ Vector3D(flat.x, flat.y, flat.x * 0.5))
        }
    }

    @Test func `sampling a parameter range starts and ends at the range bounds`() {
        let points = Self.path.points(in: 0.5...2.25, segmentation: .fixed(6))
        #expect(points.first! ≈ Self.path.point(at: 0.5))
        #expect(points.last! ≈ Self.path.point(at: 2.25))
    }
}
