import Testing
@testable import Cadova

struct NaturalUpDirectionTests {
    @Test func basics() async throws {
        try await Stack(.z, alignment: .center) {
            Cylinder(diameter: 1, height: 5)
            Cylinder(bottomDiameter: 2, topDiameter: 0, height: 2)
        }
        .readingEnvironment(\.naturalUpDirection) { arrow, globalUp in
            arrow.rotated(from: .up, to: globalUp)
        }
        .translated(z: 7)
        .repeated(around: .x, count: 8)
        .definingNaturalUpDirection()
        .expectEquals(goldenFile: "naturalUpDirection")
    }

    @Test func testDefault() async throws {
        try await Box(1)
            .readingEnvironment(\.naturalUpDirection) { body, direction in
                #expect(direction ≈ .up)
            }
            .triggerEvaluation()
    }

    @Test func perpendicularDirection() async throws {
        try await Box(1)
            .readingEnvironment(\.naturalUpDirectionXYAngle) { body, angle in
                #expect(angle == nil)
            }
            .definingNaturalUpDirection()
            .triggerEvaluation()
    }
}
