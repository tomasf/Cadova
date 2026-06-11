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

    @Test func `2D natural up direction defaults to nil`() async throws {
        // With no 2D up direction defined, the inherited up is world +Z, which has
        // no projection onto the XY plane.
        try await Rectangle(1)
            .readingEnvironment(\.naturalUpDirection2D) { body, direction in
                #expect(direction == nil)
                body
            }
            .triggerEvaluation()
    }

    @Test func `2D natural up direction is read back as defined`() async throws {
        try await Rectangle(1)
            .readingEnvironment(\.naturalUpDirection2D) { body, direction in
                #expect(direction ≈ .up)
                body
            }
            .definingNaturalUpDirection(.up)
            .triggerEvaluation()
    }

    @Test func `2D up direction is transformed correctly by surrounding rotation`() async throws {
        // Outer up = world +X. Inside a +90° rotation, the local direction that
        // points to world +X is local -Y (down).
        try await Rectangle(1)
            .readingEnvironment(\.naturalUpDirection2D) { body, direction in
                #expect(direction ≈ .down)
                body
            }
            .rotated(90°)
            .definingNaturalUpDirection(.right)
            .triggerEvaluation()
    }

    @Test func `XY angle is nil for vertical up direction despite transform rounding`() async throws {
        // A chain of opposing rotations around different axes mathematically
        // cancels to identity, but the concatenated matrix leaves sub-ulp
        // noise in the XY plane of a +Z up vector. Without an epsilon guard,
        // naturalUpDirectionXYAngle reads that noise as a real off-axis
        // component and returns a meaningless angle.
        try await Box(1)
            .readingEnvironment(\.naturalUpDirectionXYAngle) { body, angle in
                #expect(angle == nil)
            }
            .definingNaturalUpDirection(.up)
            .rotated(angle: 30°, around: Direction3D(.init(1, 2, 3)))
            .rotated(angle: -30°, around: Direction3D(.init(1, 2, 3)))
            .triggerEvaluation()
    }
}
