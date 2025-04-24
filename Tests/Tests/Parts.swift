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
}
