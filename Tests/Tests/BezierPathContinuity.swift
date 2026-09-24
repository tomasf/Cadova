import Testing
import Foundation
@testable import Cadova

/// Continuous segments place their first control point along the previous segment's end tangent, so the
/// path keeps its direction across the join.
struct BezierPathContinuityTests {
    /// Ends heading along (3, 4) / 5 from [8, 6].
    private static let base = BezierPath2D(startPoint: [0, 0])
        .addingQuadraticCurve(controlPoint: [5, 2], end: [8, 6])

    private static func expectSmoothJoin(_ path: BezierPath2D, distance: Double) {
        let previous = path.curves[path.curves.count - 2]
        let added = path.curves[path.curves.count - 1]
        #expect(added.tangent(at: 0).unitVector ≈ previous.tangent(at: 1).unitVector)
        let expectedControlPoint = Vector2D(8, 6) + Vector2D(3, 4) / 5 * distance
        #expect(added.controlPoints[1] ≈ expectedControlPoint)
    }

    @Test func `continuous line extends straight along the end tangent`() {
        let path = Self.base.addingContinuousLine(distance: 10)
        Self.expectSmoothJoin(path, distance: 10)
        #expect(path.curves.last!.controlPoints ≈ [[8, 6], [14, 14]])
    }

    @Test func `continuous quadratic curve keeps the end tangent`() {
        let path = Self.base.addingContinuousQuadraticCurve(distance: 5, end: [20, 5])
        Self.expectSmoothJoin(path, distance: 5)
        #expect(path.curves.last!.controlPoints.count == 3)
        #expect(path.curves.last!.controlPoints.last! ≈ [20, 5])
    }

    @Test func `continuous cubic curve keeps the end tangent`() {
        let path = Self.base.addingContinuousCubicCurve(distance: 2.5, controlPoint2: [18, 12], end: [20, 5])
        Self.expectSmoothJoin(path, distance: 2.5)
        #expect(path.curves.last!.controlPoints ≈ [[8, 6], [9.5, 8], [18, 12], [20, 5]])
    }

    @Test func `continuous curve of any degree keeps the end tangent`() {
        let path = Self.base.addingContinuousCurve(distance: 5, controlPoints: [15, 15], [20, 10], [22, 0], [30, 2])
        Self.expectSmoothJoin(path, distance: 5)
        #expect(path.curves.last!.controlPoints.count == 6)
    }

    @Test func `continuous segments follow a curve that arrives with no end tension`() {
        // The last control point coincides with the end, so the direction comes from the one before it.
        let path = BezierPath2D(startPoint: [0, 0])
            .addingCubicCurve(controlPoint1: [0, 10], controlPoint2: [10, 10], end: [10, 10])
            .addingContinuousLine(distance: 4)
        #expect(path.curves.last!.controlPoints ≈ [[10, 10], [14, 10]])
    }

    @Test func `builder continuous components match the path methods`() {
        let builderPath = BezierPath2D(from: [0, 0]) {
            curve(controlX: 5, controlY: 2, endX: 8, endY: 6)
            continuousLine(distance: 10)
            continuousCurve(distance: 5, endX: 30, endY: 14)
            continuousCurve(distance: 3, controlX: 40, controlY: 0, endX: 50, endY: 5)
        }

        let manualPath = Self.base
            .addingContinuousLine(distance: 10)
            .addingContinuousQuadraticCurve(distance: 5, end: [30, 14])
            .addingContinuousCubicCurve(distance: 3, controlPoint2: [40, 0], end: [50, 5])

        #expect(builderPath ≈ manualPath)
    }

    @Test func `3D builder continuous components match the path methods`() {
        let builderPath = BezierPath3D(from: [0, 0, 0]) {
            line(x: 10, y: 0, z: 5)
            continuousCurve(distance: 4, endX: 20, endY: 10, endZ: 5)
            continuousCurve(distance: 2, controlPoints: [Vector3D(25, 20, 0), [30, 20, 10]])
        }

        let manualPath = BezierPath3D(startPoint: [0, 0, 0])
            .addingLine(to: [10, 0, 5])
            .addingContinuousQuadraticCurve(distance: 4, end: [20, 10, 5])
            .addingContinuousCurve(distance: 2, controlPoints: [25, 20, 0], [30, 20, 10])

        #expect(builderPath ≈ manualPath)
    }

    @Test func `relative builder continuous curves measure their end point from the current point`() {
        let builderPath = BezierPath2D(from: [0, 0], mode: .relative) {
            line(x: 10)
            continuousCurve(distance: 5, endX: 10, endY: 10)
        }

        let manualPath = BezierPath2D(startPoint: [0, 0])
            .addingLine(to: [10, 0])
            .addingContinuousQuadraticCurve(distance: 5, end: [20, 10])

        #expect(builderPath ≈ manualPath)
        #expect(builderPath.curves.last!.controlPoints[1] ≈ [15, 0])
    }
}
