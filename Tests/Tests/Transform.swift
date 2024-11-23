import Testing
@testable import SwiftSCAD

struct TransformTests {
    @Test func affine3D() {
        Box([30, 15, 5])
            .transformed(
                .identity
                    .translated(x: -5)
                    .scaled(y: 0.3)
                    .rotated(z: 90°)
                    .sheared(.x, along: .y, angle: 45°)
                    .rotated(x: 90°)
            )
            .expectCodeEquals(file: "transform3d")

        #expect(AffineTransform3D.translation(z: 3).offset.z ≈ 3.0)
    }

    @Test func transform2DTo3D() {
        let transforms2D: [AffineTransform2D] = [
            .translation(x: 10, y: 3),
            .scaling(x: 3, y: 9),
            .rotation(30°),
            .translation(x: 10, y: 5)
                .scaled(x: 2)
                .rotated(15°)
        ]

        let transforms3D: [SwiftSCAD.AffineTransform3D] = [
            .translation(x: 10, y: 3),
            .scaling(x: 3, y: 9),
            .rotation(z: 30°),
            .translation(x: 10, y: 5)
                .scaled(x: 2)
                .rotated(z: 15°)
        ]

        let samplePoints: [Vector3D] = [
            [20, 15, 0],
            [0, 0, 0],
            [-5, 100, 0],
            [-1, -12.8, 0],
        ]
        
        for (index, transform2D) in transforms2D.enumerated() {
            let transform3D = transforms3D[index]
            let converted3D = AffineTransform3D(transform2D)

            #expect(transform3D.values ≈ converted3D.values)

            for samplePoint in samplePoints {
                #expect(transform3D.apply(to: samplePoint).xy ≈ transform2D.apply(to: samplePoint.xy))
                #expect(converted3D.apply(to: samplePoint) ≈ transform3D.apply(to: samplePoint))
            }
        }
    }
}
