import Testing
@testable import Cadova

struct SplitTests {
    @Test func splitAlongPlane() async throws {
        let split = Box(10)
            .aligned(at: .center)
            .split(along: .z(0).rotated(x: 20°)) {
                $0.colored(.red)
                $1.colored(.blue)
            }

        try await split.expectEquals(goldenFile: "splitAlongPlane")
    }

    @Test func separated() async throws {
        try await Box(1).adding { Box(1).translated(x: 0.5) }
            .separated { #expect($0.count == 1) }
            .triggerEvaluation()

        try await Box(1).adding { Box(1).translated(x: 1.1) }
            .separated { #expect($0.count == 2) }
            .triggerEvaluation()
    }

    @Test func separatedExample() async throws {
        let model = Sphere(diameter: 10)
            .subtracting {
                Box([12, 12, 1])
                    .aligned(at: .center)
            }

        try await
        model.separated { components in
            Stack(.x, spacing: 1) {
                for component in components {
                    component
                }
            }
        }
        .expectEquals(goldenFile: "separatedExample")
    }
}
