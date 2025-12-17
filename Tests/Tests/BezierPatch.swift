import Testing
@testable import Cadova

struct BezierPatchTests {
    @Test func `bezier patch can be enclosed into solid geometry`() async throws {
        let patch = BezierPatch(controlPoints: [
            [ [0, 0, 0],   [1, 0, 0.8],   [2, 0, -0.2],  [3, 0, 0] ],
            [ [0, 1, 0.5], [1, 1, 1.5],   [2, 1, 0.3],   [3, 1, -0.4] ],
            [ [0, 2, 0.4], [1, 2, 1.2],   [2, 2, 1],     [3, 2, 0.2] ],
            [ [0, 3, 0],   [1, 3, 0.4],   [2, 3, 0.1],   [3, 3, 1.2] ]
        ])

        try await patch.enclosed(against: Plane.z(-0.5))
            .aligned(at: .bottom)
            .expectEquals(goldenFile: "bezierPatchBasic")
    }
}
