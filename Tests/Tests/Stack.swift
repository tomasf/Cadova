import Testing
@testable import Cadova

struct StackTests {
    @Test func `stack ignores alignment on its own axis`() async throws {
        // The Z part of the alignment should be ignored
        try await Stack(.z, alignment: .center) {
            Cylinder(diameter: 1, height: 1)
            Cylinder(bottomDiameter: 0, topDiameter: 3, height: 1)
            Cylinder(diameter: 3, height: 2)
        }
        .expectEquals(goldenFile: "zstack")
    }
}
