import Testing
@testable import Cadova

struct StrokeCurveTests {
    private let linePath = BezierPath2D(linesBetween: [[0, 0], [10, 0]])
    private let cornerPath = BezierPath2D(linesBetween: [[0, 0], [10, 0], [10, 10]])

    @Test func `centered curve stroke uses butt caps by default`() async throws {
        let geometry = linePath.stroked(width: 2, alignment: .centered, style: .miter)
        let area = try await geometry.measurements.area
        let bounds = try await geometry.bounds

        #expect(area ≈ 20)
        #expect(bounds != nil)
        #expect(bounds!.minimum ≈ [0, -1])
        #expect(bounds!.maximum ≈ [10, 1])
    }

    @Test func `centered curve stroke with round caps adds circular ends`() async throws {
        let geometry = linePath
            .stroked(width: 2, alignment: .centered, style: .miter)
            .withLineCapStyle(.round)
        let area = try await geometry.measurements.area
        let bounds = try await geometry.bounds

        #expect(area.equals(20 + Double.pi, within: 0.02))
        #expect(bounds != nil)
        #expect(bounds!.minimum.equals([-1, -1], within: 0.01))
        #expect(bounds!.maximum.equals([11, 1], within: 0.01))
    }

    @Test func `centered curve stroke with square caps extends bounds`() async throws {
        let geometry = linePath
            .stroked(width: 2, alignment: .centered, style: .miter)
            .withLineCapStyle(.square)
        let area = try await geometry.measurements.area
        let bounds = try await geometry.bounds

        #expect(area ≈ 24)
        #expect(bounds != nil)
        #expect(bounds!.minimum ≈ [-1, -1])
        #expect(bounds!.maximum ≈ [11, 1])
    }

    @Test func `aligned curve strokes stay on one side of the path`() async throws {
        let leftStroke = linePath.stroked(width: 2, alignment: .left, style: .miter)
        let rightStroke = linePath.stroked(width: 2, alignment: .right, style: .miter)
        let leftBounds = try await leftStroke.bounds
        let rightBounds = try await rightStroke.bounds

        #expect(leftBounds != nil)
        #expect(leftBounds!.minimum ≈ [0, 0])
        #expect(leftBounds!.maximum ≈ [10, 2])

        #expect(rightBounds != nil)
        #expect(rightBounds!.minimum ≈ [0, -2])
        #expect(rightBounds!.maximum ≈ [10, 0])
    }

    @Test func `curve stroke miter join matches expected area and bounds`() async throws {
        let geometry = cornerPath.stroked(width: 2, alignment: .centered, style: .miter)
        let area = try await geometry.measurements.area
        let bounds = try await geometry.bounds

        #expect(area ≈ 40)
        #expect(bounds != nil)
        #expect(bounds!.minimum ≈ [0, -1])
        #expect(bounds!.maximum ≈ [11, 10])
    }

    @Test func `curve stroke bevel join matches expected area and bounds`() async throws {
        let geometry = cornerPath.stroked(width: 2, alignment: .centered, style: .bevel)
        let area = try await geometry.measurements.area
        let bounds = try await geometry.bounds

        #expect(area ≈ 39.5)
        #expect(bounds != nil)
        #expect(bounds!.minimum ≈ [0, -1])
        #expect(bounds!.maximum ≈ [11, 10])
    }

    @Test func `curve stroke round join matches expected area and bounds`() async throws {
        let geometry = cornerPath.stroked(width: 2, alignment: .centered, style: .round)
        let area = try await geometry.measurements.area
        let bounds = try await geometry.bounds

        #expect(area.equals(39 + Double.pi / 4, within: 0.06))
        #expect(bounds != nil)
        #expect(bounds!.minimum ≈ [0, -1])
        #expect(bounds!.maximum ≈ [11, 10])
    }
}
