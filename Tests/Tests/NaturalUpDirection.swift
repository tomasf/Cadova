import Testing
@testable import Cadova

struct NaturalUpDirectionTests {
    @Test func `natural up direction propagates through geometry tree`() async throws {
        try await Stack(.z, alignment: .center) {
            Cylinder(diameter: 1, height: 5)
            Cylinder(bottomDiameter: 2, topDiameter: 0, height: 2)
        }
        .readingEnvironment(\.naturalUpDirection) { arrow, up in
            arrow.rotated(from: .up, to: up)
        }
        .translated(z: 7)
        .repeated(around: .x, count: 8)
        .definingNaturalUpDirection()
        .expectEquals(goldenFile: "naturalUpDirection")
    }

    @Test func `natural up direction defaults to positive Z`() async throws {
        try await Box(1)
            .readingEnvironment(\.naturalUpDirection) { body, direction in
                #expect(direction ≈ .up)
            }
            .triggerEvaluation()
    }

    @Test func `perpendicular direction returns nil XY angle`() async throws {
        try await Box(1)
            .readingEnvironment(\.naturalUpDirectionXYAngle) { body, angle in
                #expect(angle == nil)
            }
            .definingNaturalUpDirection()
            .triggerEvaluation()
    }
}
