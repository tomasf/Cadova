import Testing
@testable import Cadova

struct SplitTests {
    @Test func splitAlongPlane() async throws {
        let split = Box(10)
            .aligned(at: .center)
            .split(along: Plane(z: 0).rotated(x: 20°)) {
                $0.colored(.red)
                $1.colored(.blue)
            }

        try await split.expectEquals(goldenFile: "splitAlongPlane")
    }
}
