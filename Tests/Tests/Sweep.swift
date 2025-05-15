import Foundation
import Testing
@testable import Cadova

struct SweepTests {
    @Test func twist() async throws {
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
            .swept(along: path, pointing: .down, toward: .down)
            .withSegmentation(minAngle: 4°, minSize: 0.3)

        let m = await sweep.measurements

        #expect(m.volume ≈ 11539.408)
        #expect(m.surfaceArea ≈ 18055.813)
        #expect(m.boundingBox ≈ .init(minimum: [0.195, -5.603, -3], maximum: [105.831, 99.805, 155.5]))
    }
}
