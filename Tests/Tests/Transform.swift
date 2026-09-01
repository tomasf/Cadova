import Testing
@testable import Cadova

struct TransformTests {
    /*
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
*/
    
    @Test func `axis shearing displaces the named axis in both dimensionalities`() {
        let shear2D = Transform2D.shearing(.x, factor: 0.5)
        #expect(shear2D.apply(to: Vector2D(0, 1)) ≈ Vector2D(0.5, 1))
        #expect(shear2D.apply(to: Vector2D(1, 0)) ≈ Vector2D(1, 0))

        let shear3D = Transform3D.shearing(.x, along: .z, factor: 0.5)
        #expect(shear3D.apply(to: Vector3D(0, 0, 1)) ≈ Vector3D(0.5, 0, 1))
        #expect(shear3D.apply(to: Vector3D(1, 0, 0)) ≈ Vector3D(1, 0, 0))
    }

    @Test func `2D transforms convert correctly to 3D`() {
        let transforms2D: [Transform2D] = [
            .translation(x: 10, y: 3),
            .scaling(x: 3, y: 9),
            .rotation(30°),
            .shearing(.x, factor: 0.4),
            .shearing(.y, angle: 20°),
            .translation(x: 10, y: 5)
                .scaled(x: 2)
                .rotated(15°)
        ]

        let transforms3D: [Transform3D] = [
            .translation(x: 10, y: 3),
            .scaling(x: 3, y: 9),
            .rotation(z: 30°),
            .shearing(.x, along: .y, factor: 0.4),
            .shearing(.y, along: .x, angle: 20°),
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
            let converted3D = Transform3D(transform2D)

            #expect(transform3D.values ≈ converted3D.values)

            for samplePoint in samplePoints {
                #expect(transform3D.apply(to: samplePoint).xy ≈ transform2D.apply(to: samplePoint.xy))
                #expect(converted3D.apply(to: samplePoint) ≈ transform3D.apply(to: samplePoint))
            }
        }
    }
}
