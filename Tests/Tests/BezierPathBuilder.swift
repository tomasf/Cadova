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

    @Test func `absolute arcs sweep less than a full turn to an end angle given past 360 degrees`() {
        // The start angle is measured in -180°...180°, so starting at (0, -10) is -90°. Reaching 360° from
        // there is a quarter turn counterclockwise, not a turn and a quarter.
        let counterclockwise = BezierPath2D(startPoint: [0, -10]).addingArc(center: .zero, to: 360°, clockwise: false)
        #expect(counterclockwise.point(at: counterclockwise.domain.upperBound) ≈ [10, 0])
        #expect(counterclockwise.length(segmentation: .fixed(100)).equals(5 * .pi, within: 0.01))

        let clockwise = BezierPath2D(startPoint: [0, 10]).addingArc(center: .zero, to: -360°, clockwise: true)
        #expect(clockwise.point(at: clockwise.domain.upperBound) ≈ [10, 0])
        #expect(clockwise.length(segmentation: .fixed(100)).equals(5 * .pi, within: 0.01))
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

    @Test func `curve handles are offsets from their own anchors`() {
        let armRoot = Vector3D(0, 0, 44)
        let armBend = Vector3D(0, 30, 32)
        let ballCenter = Vector3D(0, 46, 34)

        let handlePath = BezierPath3D(startPoint: armRoot)
            .addingCurve(to: armBend, leaving: [0, 20, 0], arriving: [0, 0, 8])
            .addingCurve(to: ballCenter, leaving: [0, 0, -10], arriving: [0, -2, -12])

        let builderPath = BezierPath3D(from: armRoot) {
            curve(to: armBend, leaving: [0, 20, 0], arriving: [0, 0, 8])
            curve(to: ballCenter, leaving: [0, 0, -10], arriving: [0, -2, -12])
        }

        let manualPath = BezierPath3D(startPoint: armRoot)
            .addingCurve(armRoot + [0, 20, 0], armBend + [0, 0, 8], armBend)
            .addingCurve(armBend - [0, 0, 10], ballCenter - [0, 2, 12], ballCenter)

        #expect(handlePath ≈ manualPath)
        #expect(builderPath ≈ manualPath)
    }

    @Test func `curve with a leaving length continues the current direction`() {
        let builderPath = BezierPath3D(from: [0, 0, 44]) {
            curve(to: [0, 30, 32], leaving: [0, 20, 0], arriving: [0, 0, 8])
            curve(to: [0, 46, 34], leaving: 10, arriving: [0, -2, -12])
        }

        let manualPath = BezierPath3D(startPoint: [0, 0, 44])
            .addingCubicCurve(controlPoint1: [0, 20, 44], controlPoint2: [0, 30, 40], end: [0, 30, 32])
            .addingCubicCurve(controlPoint1: [0, 30, 22], controlPoint2: [0, 44, 22], end: [0, 46, 34])

        #expect(builderPath ≈ manualPath)
    }

    @Test func `curve with one handle is quadratic`() {
        let builderPath = BezierPath2D(from: [0, 0]) {
            curve(to: [10, 10], leaving: [5, 0])
            curve(to: [20, 0], arriving: [0, 5])
            curve(to: [30, 0], leaving: 4)
        }

        let manualPath = BezierPath2D(startPoint: [0, 0])
            .addingQuadraticCurve(controlPoint: [5, 0], end: [10, 10])
            .addingQuadraticCurve(controlPoint: [20, 5], end: [20, 0])
            .addingQuadraticCurve(controlPoint: [20, -4], end: [30, 0])

        #expect(builderPath ≈ manualPath)
    }

    @Test func `relative mode moves the end point but not the handles`() {
        let builderPath = BezierPath2D(from: [10, 10], mode: .relative) {
            curve(to: [20, 0], leaving: [0, 5], arriving: [0, 5])
            curve(to: [5, 5], leaving: [3, 0]).absolute
        }

        let manualPath = BezierPath2D(startPoint: [10, 10])
            .addingCubicCurve(controlPoint1: [10, 15], controlPoint2: [30, 15], end: [30, 10])
            .addingQuadraticCurve(controlPoint: [33, 10], end: [5, 5])

        #expect(builderPath ≈ manualPath)
    }
}
