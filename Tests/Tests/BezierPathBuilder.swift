import Testing
@testable import SwiftSCAD

struct BezierPathBuilderTests {
    @Test func testAbsolute() {
        let builderPath = BezierPath2D(from: [10, 4]) {
            line(x: 22, y: 1)
            line(x: 2)
            line(y: 76)
            curve(
                controlX: 7, controlY: 12,
                endX: 77, endY: 18
            )
            line()
            curve(
                controlX: 96, controlY: 27,
                controlX: 127, controlY: 1.5,
                endX: 23.6, endY: 1
            )
        }

        let manualPath = BezierPath2D(startPoint: [10, 4])
            .addingLine(to: [22, 1])
            .addingLine(to: [2, 1])
            .addingLine(to: [2, 76])
            .addingQuadraticCurve(controlPoint: [7, 12], end: [77, 18])
            .addingLine(to: [77, 18])
            .addingCubicCurve(controlPoint1: [96, 27], controlPoint2: [127, 1.5], end: [23.6, 1])

        #expect(builderPath ≈ manualPath)
    }

    @Test func testRelative() {
        let builderPath = BezierPath2D(from: [10, 4], mode: .relative) {
            line(x: 22, y: 1)
            line(x: 2)
            line(y: 74)
            if true {
                line(y: 2)
            }
            curve(
                controlX: 7, controlY: 12,
                endX: 77, endY: 18
            )
            line()
            curve(
                controlX: 96, controlY: 27,
                controlX: 127, controlY: 1.5,
                endX: 23.6, endY: 1
            )
        }

        let manualPath = BezierPath2D(startPoint: [10, 4])
            .addingLine(to: [32, 5])
            .addingLine(to: [34, 5])
            .addingLine(to: [34, 79])
            .addingLine(to: [34, 81])
            .addingQuadraticCurve(controlPoint: [41, 93], end: [111, 99])
            .addingLine(to: [111, 99])
            .addingCubicCurve(controlPoint1: [207, 126], controlPoint2: [238, 100.5], end: [134.6, 100])

        #expect(builderPath ≈ manualPath)
    }
}
