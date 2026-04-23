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

    @Test func `tag references include definitions from nested and outer booleans`() async throws {
        let sharedTag = Tag("shared tag")

        let geometry = Box(x: 21, y: 1, z: 1)
            .subtracting {
                sharedTag
            }
            .adding {
                Box(1)
                    .tagged(sharedTag)
                    .subtracting { Box(1) }
                    .translated(x: 5)
            }
            .adding {
                Box(1)
                    .tagged(sharedTag)
                    .subtracting { Box(1) }
                    .translated(x: 15)
            }

        #expect(try await geometry.measurements.volume ≈ 19)
    }

    @Test func `tag can read definitions as separate members`() async throws {
        let sharedTag = Tag("shared tag")

        let geometry = Box(x: 21, y: 1, z: 1)
            .subtracting {
                sharedTag
            }
            .adding {
                Box(1)
                    .tagged(sharedTag)
                    .subtracting { Box(1) }
                    .translated(x: 5)
            }
            .adding {
                Box(1)
                    .tagged(sharedTag)
                    .subtracting { Box(1) }
                    .translated(x: 15)
            }
            .adding {
                sharedTag.readingMembers { members in
                    for (index, member) in members.enumerated() {
                        member.translated(y: Double(index) * 10)
                    }
                }
            }

        let bounds = try await geometry.bounds
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 21)
        #expect(bounds?.maximum.y ≈ 11)
        #expect(try await geometry.measurements.volume ≈ 21)
    }

    @Test func `tag can map each member separately`() async throws {
        let sharedTag = Tag("shared tag")

        let geometry = Box(1)
            .tagged(sharedTag)
            .translated(x: 5)
            .adding {
                Box(1)
                    .tagged(sharedTag)
                    .translated(x: 15)
            }
            .adding {
                sharedTag.map { member in
                    member.translated(z: 10)
                }
            }

        let bounds = try await geometry.bounds
        #expect(bounds?.minimum.x ≈ 5)
        #expect(bounds?.maximum.x ≈ 16)
        #expect(bounds?.maximum.z ≈ 11)
        #expect(try await geometry.measurements.volume ≈ 4)
    }
}
