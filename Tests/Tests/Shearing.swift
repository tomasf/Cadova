import Testing
import Foundation
@testable import Cadova

struct ShearingTests {
    private let samplePoints3D: [Vector3D] = [
        [0, 0, 0], [1, 0, 0], [0, 1, 0], [3, -7, 0],
        [0, 0, 1], [2, 5, -3], [-4, 0.5, 12]
    ]

    @Test func `3D shearing aims a direction at another`() {
        let target = Direction3D(x: 0.3, y: -0.1, z: 1)
        let transform = Transform3D.shearing(from: .up, to: target)
        let leaned = transform.apply(to: Vector3D(0, 0, 1))

        #expect(Direction3D(leaned) ≈ target)
        #expect(leaned.z ≈ 1)
    }

    @Test func `3D shearing keeps the perpendicular plane fixed`() {
        let transform = Transform3D.shearing(from: .up, to: Direction3D(x: 0.3, y: -0.1, z: 1))

        for point in samplePoints3D where point.z == 0 {
            #expect(transform.apply(to: point) ≈ point)
        }
        for point in samplePoints3D {
            #expect(transform.apply(to: point).z ≈ point.z)
        }
    }

    @Test func `3D shearing matches a pair of axis shears`() {
        let target = Direction3D(x: 0.3, y: -0.1, z: 1)
        let factorX = target.x / target.z
        let factorY = target.y / target.z

        let composed = Transform3D.identity
            .sheared(.x, along: .z, factor: factorX)
            .sheared(.y, along: .z, factor: factorY)

        #expect(Transform3D.shearing(from: .up, to: target) ≈ composed)
    }

    @Test func `shearing towards the same direction does nothing`() {
        #expect(Transform3D.shearing(from: .up, to: .up).isIdentity)
        #expect(Transform2D.shearing(from: .right, to: .right).isIdentity)

        let diagonal = Transform3D.shearing(from: Direction3D(x: 1, z: 1), to: Direction3D(x: 2, z: 2))
        #expect(diagonal.isApproximatelyEqual(to: .identity))
    }

    @Test func `3D shearing works from an arbitrary direction`() {
        let source = Direction3D(x: 1, y: 0, z: 1)
        let target = Direction3D(x: 1, y: 0.4, z: 0.2)
        let transform = Transform3D.shearing(from: source, to: target)

        #expect(Direction3D(transform.apply(to: source.unitVector)) ≈ target)

        // Vectors in the plane perpendicular to the source are untouched, and every point keeps its
        // position along the source direction.
        for perpendicular in [Vector3D(1, 0, -1).normalized, Vector3D(0, 1, 0)] {
            #expect(transform.apply(to: perpendicular) ≈ perpendicular)
        }
        for point in samplePoints3D {
            let expected = point ⋅ source.unitVector
            let actual = transform.apply(to: point) ⋅ source.unitVector
            #expect(actual ≈ expected)
        }
    }

    @Test func `3D shearing stretches only along the sheared direction`() {
        let angle = 25°
        let target = Direction3D(from: .right, elevation: 90° - angle)
        let transform = Transform3D.shearing(from: .up, to: target)
        let expectedLength = 1.0 / cos(angle)

        #expect(transform.apply(to: Vector3D(0, 0, 1)).magnitude ≈ expectedLength)
        #expect(transform.apply(to: Vector3D(0, 0, 1)) ≈ Vector3D(tan(angle), 0, 1))
    }

    @Test func `2D shearing aims a direction at another`() {
        let target = Direction2D(x: 0.5, y: 1)
        let transform = Transform2D.shearing(from: .up, to: target)
        let leaned = transform.apply(to: Vector2D(0, 1))

        #expect(Direction2D(leaned) ≈ target)
        #expect(leaned ≈ Vector2D(0.5, 1))
        #expect(transform.apply(to: Vector2D(3, 0)) ≈ Vector2D(3, 0))
    }

    @Test func `sheared geometry keeps its volume and height`() async throws {
        let box = Box([10, 10, 20])
        let sheared = box.sheared(to: Direction3D(x: 0.4, y: 0.25, z: 1))
        let measurements = try await sheared.measurements

        #expect(measurements.volume ≈ 2000)
        #expect(measurements.boundingBox?.size.z ≈ 20)
        #expect(measurements.boundingBox?.size.x ≈ 18)
        #expect(measurements.boundingBox?.size.y ≈ 15)
    }

    @Test func `sheared 2D geometry keeps its area`() async throws {
        let sheared = Rectangle([10, 20]).sheared(to: Direction2D(x: 0.5, y: 1))
        let measurements = try await sheared.measurements

        #expect(measurements.area ≈ 200)
        #expect(measurements.boundingBox?.size ≈ [20, 20])
    }
}
