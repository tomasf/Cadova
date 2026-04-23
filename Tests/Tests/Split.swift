import Testing
@testable import Cadova

struct SplitTests {
    @Test func `geometry can be split along angled plane`() async throws {
        let split = Box(10)
            .aligned(at: .center)
            .split(along: .z(0).rotated(x: 20°)) {
                $0.colored(.red)
                $1.colored(.blue)
            }

        try await split.expectEquals(goldenFile: "splitAlongPlane")
    }

    @Test func `split parts have correct measurements`() async throws {
        let topMeasurements = try await Box(10)
            .split(along: .z(2)) { a, _ in a }
            .measurements

        #expect(topMeasurements.volume ≈ 800.0)
        #expect(topMeasurements.boundingBox?.minimum.z ≈ 2)

        let bottomMeasurements = try await Box(10)
            .split(along: .z(2)) { _, b in b }
            .measurements

        #expect(bottomMeasurements.volume ≈ 200.0)
        #expect(bottomMeasurements.boundingBox?.minimum.z ≈ 0)
    }

    @Test func `separated correctly identifies disjoint components`() async throws {
        let merged: any Geometry3D = Box(1).adding { Box(1).translated(x: 0.5) }
            .separated { components in
                #expect(components.count == 1)
                Union(children: components)
            }
        try await merged.triggerEvaluation()

        let merged2: any Geometry3D = Box(1).adding { Box(1).translated(x: 1.1) }
            .separated { components in
                #expect(components.count == 2)
                Union(children: components)
            }
        try await merged2.triggerEvaluation()
    }

    @Test func `separated components can be stacked`() async throws {
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
