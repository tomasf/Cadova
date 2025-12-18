import Foundation
import Testing
@testable import Cadova

struct SweepTests {
    @Test func `shape can be swept along 3D bezier path`() async throws {
        let shape = Rectangle(x: 10, y: 6)
            .aligned(at: .center)
            .adding {
                Circle(diameter: 5)
                    .translated(x: 2, y: 3)
            }
            .subtracting {
                Rectangle(x: 8, y: 4)
                    .aligned(at: .center)
            }

        let path = BezierPath3D {
            line(x: 50)
            curve(controlX: 100, controlY: 0, controlZ: 0, endX: 100, endY: 0, endZ: 50)
            curve(controlX: 100, controlY: 0, controlZ: 150, endX: 100, endY: 50, endZ: 150)
            line(y: 100)
        }

        let sweep = shape
            .swept(along: path, pointing: .down, toward: .direction(.down))
            .withSegmentation(minAngle: 4°, minSize: 0.3)

        let m = try await sweep.measurements

        #expect(m.volume ≈ 11652.703)
        #expect(m.surfaceArea ≈ 18070.729)
        #expect(m.boundingBox ≈ .init(minimum: [0, -5.595, -3], maximum: [105.831, 100, 155.5]))
    }

    @Test func `star shape can be swept along 2D path`() async throws {
        let path = BezierPath2D {
            curve([10, 65], [50, -20], [60, 50])
        }

        let sweep = ExampleTests.Star(pointCount: 5, radius: 10, pointRadius: 1, centerSize: 4)
            .swept(along: path)
        let m = try await sweep.measurements

        #expect(m.volume ≈ 13096.084)
        #expect(m.surfaceArea ≈ 9237.344)
        #expect(m.boundingBox ≈ .init(minimum: [-10.8721, -1.38221, -10.5105], maximum: [68.9987, 51.5556, 10.5105]))
    }
}
