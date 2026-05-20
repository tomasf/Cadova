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

    @Test func `up direction is preserved when defined inside a rotated scope`() async throws {
        try await Box(1)
            .readingEnvironment(\.naturalUpDirection) { body, direction in
                #expect(direction ≈ .up)
                body
            }
            .definingNaturalUpDirection(.up)
            .rotated(x: 90°)
            .triggerEvaluation()
    }

    @Test func `up direction is transformed correctly by surrounding rotation`() async throws {
        // Outer up = world +Y. Inside a +90° rotation around X, the local axis that
        // points to world +Y is local -Z.
        try await Box(1)
            .readingEnvironment(\.naturalUpDirection) { body, direction in
                #expect(direction ≈ .negativeZ)
                body
            }
            .rotated(x: 90°)
            .definingNaturalUpDirection(.positiveY)
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
