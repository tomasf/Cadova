import Foundation
import Testing
@testable import Cadova

struct DeformTests {
    @Test func basic2D() async throws {
        let deformation = Rectangle(x: 50, y: 10)
            .deformed(using: BezierPath2D(from: [5, 0]) {
                curve(controlX: 30, controlY: 50, endX: 45, endY: 0)
            }, with: .x)

        let m = try await deformation.measurements
        #expect(m.area ≈ 500)
        #expect(m.boundingBox ≈ .init(minimum: [0, -20.8497], maximum: [50, 35]))
    }

    @Test func basic2Din3D() async throws {
        let deformation = Box(x: 100, y: 3, z: 20)
            .deformed(using: BezierPath2D {
                curve(controlX: 50, controlY: 50, endX: 100, endY: 0)
            }, with: .x)
            .withSegmentation(count: 100)

        let m = try await deformation.measurements

        #expect(m.volume ≈ 6000)
        #expect(m.surfaceArea ≈ 5311.032)
        #expect(m.boundingBox ≈ .init(minimum: .zero, maximum: [100, 28, 20]))
    }
}
