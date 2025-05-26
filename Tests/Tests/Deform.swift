import Foundation
import Testing
@testable import Cadova

struct DeformTests {
    @Test func basic2Din3D() async throws {
        let deformation = Box(x: 100, y: 3, z: 20)
            .deformed(using: BezierPath2D {
                curve(controlX: 50, controlY: 50, endX: 100, endY: 0)
            }, with: .x)
            .withSegmentation(count: 100)

        let m = try await deformation.measurements

        #expect(m.volume ≈ 6000.044)
        #expect(m.surfaceArea ≈ 5311.031)
        #expect(m.boundingBox ≈ .init(minimum: .zero, maximum: [100, 27.998, 20]))
    }
}
