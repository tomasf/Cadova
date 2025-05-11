import Testing
@testable import Cadova

struct PartTests {
    @Test func separatePart() async throws {
        try await Box(10)
            .adding {
                Sphere(diameter: 5)
                    .inPart(named: "separate")
            }
            .translated(y: 10)
            .expectEquals(goldenFile: "separatePart")
    }

    @Test func nestedPartsSurvive() async throws {
        let g = Box(10)
            .adding {
                Sphere(diameter: 10)
                    .inPart(named: "inner")
                    .adding {
                        Sphere(diameter: 5)
                    }
                    .inPart(named: "outer")
            }
            .translated(x: 10)

        let partNames = await g.parts.map(\.key.name)
        #expect(partNames == ["inner", "outer"])
    }

    @Test func partsWithEqualNamesAreMerged() async throws {
        let g = Box(10)
            .adding {
                Sphere(diameter: 5)
                    .inPart(named: "merged")
            }
            .subtracting {
                Box(x: 20, y: 4, z: 4)
                    .inPart(named: "merged")
            }

        let node = try await #require(g.parts[.named("merged", type: .solid)]?.node)
        let concrete = await node.evaluate(in: .init()).concrete
        #expect(BoundingBox3D(concrete.bounds) ≈ BoundingBox3D(minimum: [-2.5, -2.5, -2.5], maximum: [20, 4, 4]))
    }

    @Test func rootOperationShouldBePositive() async throws {
        await Box(10)
            .subtracting {
                Sphere(diameter: 10)
                    .readingOperation { op in
                        #expect(op == .addition)
                    }
                    .inPart(named: "subtracted")
            }
            .triggerEvaluation()
    }
}
