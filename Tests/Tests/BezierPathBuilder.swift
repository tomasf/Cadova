import Testing
@testable import Cadova

struct BezierPathBuilderTests {
    @Test func `builder with absolute coordinates matches manual construction`() {
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

    @Test func `builder supports relative arc commands`() async throws {
        let builderPath = BezierPath2D(from: [-5, 0], mode: .relative) {
            line(y: 10)
            clockwiseArc(centerX: 5, angle: 180°)
            line(y: -10)
        }

        let manualPath = BezierPath2D(startPoint: [-5, 0])
            .addingLine(to: [-5, 10])
            .addingArc(center: [0, 10], to: 0°, clockwise: true)
            .addingLine(to: [5, 0])

        #expect(builderPath ≈ manualPath)
    }

    @Test func `builder with relative coordinates matches manual construction`() {
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

    @Test func `builder absolute arcs sweep to an absolute end angle`() {
        let builderPath = BezierPath2D(from: [10, 0]) {
            counterclockwiseArc(center: [0, 0], angle: 90°)
            clockwiseArc(center: [0, 20], angle: 0°)
        }

        let manualPath = BezierPath2D(startPoint: [10, 0])
            .addingArc(center: .zero, to: 90°, clockwise: false)
            .addingArc(center: [0, 20], to: 0°, clockwise: true)

        #expect(builderPath ≈ manualPath)
        #expect(builderPath.point(at: builderPath.domain.upperBound) ≈ [10, 20])
    }

    @Test func `builder relative arcs sweep by an angle from the current point`() {
        let builderPath = BezierPath2D(from: [10, 0], mode: .relative) {
            counterclockwiseArc(centerX: -10, angle: 90°)
            counterclockwiseArc(centerY: -5, angle: 90°)
        }

        let manualPath = BezierPath2D(startPoint: [10, 0])
            .addingArc(center: .zero, to: 90°, clockwise: false)
            .addingArc(center: [0, 5], to: 180°, clockwise: false)

        #expect(builderPath ≈ manualPath)
        #expect(builderPath.point(at: builderPath.domain.upperBound) ≈ [-5, 5])
    }
}
