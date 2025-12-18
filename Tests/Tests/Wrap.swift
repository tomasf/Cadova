import Testing
@testable import Cadova

struct WrapTests {
    @Test func `geometry can be wrapped around sphere`() async throws {
        try await Box([40, 30, 3])
            .aligned(at: .centerXY)
            .adding {
                Sphere(diameter: 3)
                    .translated(z: 3)
                    .repeated(along: .x, step: 5, count: 7)
                    .repeated(along: .y, step: 5, count: 5)
                    .aligned(at: .centerXY)
            }
            .aligned(at: .left)
            .adding {
                Cylinder(diameter: 2, height: 30)
                    .rotated(x: -90°)
                    .aligned(at: .centerY)
                    .translated(z: 3)
                    .within(x: 0...)
                    .colored(.red)
            }
            .wrappedAroundSphere(diameter: 30)
            .expectEquals(goldenFile: "wrapAroundSphere")
    }
}
