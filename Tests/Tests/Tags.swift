import Testing
@testable import Cadova

struct TagTests {
    @Test func `tagged geometry can be referenced elsewhere in tree`() async throws {
        let blueBoxInside = Tag("blue box inside")

        let geometry = Stack(.z, spacing: 3, alignment: .center) {
            Box(4)
                .colored(.green)

            Box(10)
                .aligned(at: .center)
                .subtracting {
                    // Tag a geometry at any point in your geometry tree...
                    Cylinder(diameter: 8, height: 10)
                        .tagged(blueBoxInside)
                        .rotated(x: -90°)
                        .aligned(at: .center)
                }
                .colored(.blue)
        }
        // ...
        .adding {
            // ...and refer to that same geometry later, preserving its original transform.
            Cylinder(diameter: 1, height: 20)
                .intersecting {
                    blueBoxInside
                }
                .colored(.red)
        }

        try await geometry.expectEquals(goldenFile: "tags/tags")
        #expect(try await geometry.bounds ≈ .init(minimum: [-5, -5, 0], maximum: [5, 5, 17]))
        #expect(try await geometry.measurements.volume ≈ 567.631)
    }
}
