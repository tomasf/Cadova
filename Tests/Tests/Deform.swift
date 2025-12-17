import Foundation
import Testing
@testable import Cadova

struct DeformTests {
    @Test func `2D shape can be deformed along bezier path`() async throws {
        let deformation = Rectangle(x: 50, y: 10)
            .deformed(by: BezierPath2D(from: [5, 0]) {
                curve(controlX: 30, controlY: 50, endX: 45, endY: 0)
            })

        let m = try await deformation.measurements
        #expect(m.area ≈ 499.992)
        #expect(m.boundingBox ≈ .init(minimum: [0, -20.8497], maximum: [50, 34.999]))
    }

    @Test func `3D shape can be deformed along 2D bezier path`() async throws {
        let deformation = Box(x: 100, y: 3, z: 20)
            .deformed(by: BezierPath2D {
                curve(controlX: 50, controlY: 50, endX: 100, endY: 0)
            })
            .withSegmentation(count: 100)

        let m = try await deformation.measurements

        #expect(m.volume ≈ 5999.99)
        #expect(m.surfaceArea ≈ 5311.03)
        #expect(m.boundingBox ≈ .init(minimum: .zero, maximum: [100, 27.998, 20]))
    }
}
