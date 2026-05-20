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

    @Test func `direct transform on tag reference translates it`() async throws {
        let t = Tag()
        let geometry = Box(1)
            .tagged(t)
            .adding {
                t.translated(x: 10)
            }

        let bounds = try await geometry.bounds
        #expect(bounds?.minimum ≈ [0, 0, 0])
        #expect(bounds?.maximum ≈ [11, 1, 1])
    }

    @Test func `chained transforms on tag reference compose`() async throws {
        let t = Tag()
        let geometry = Box(2)
            .tagged(t)
            .adding {
                t.translated(x: 10).translated(y: 5)
            }

        let bounds = try await geometry.bounds
        #expect(bounds?.minimum ≈ [0, 0, 0])
        #expect(bounds?.maximum ≈ [12, 7, 2])
    }

    @Test func `rotation chained with translation on tag reference applies in order`() async throws {
        // Box(2,1,1) rotated 90° around z: (x,y,z) → (-y, x, z), so corners (0..2, 0..1, 0..1)
        // become (-1..0, 0..2, 0..1). Then translated by x:5 → (4..5, 0..2, 0..1).
        let t = Tag()
        let geometry = Box([2, 1, 1])
            .tagged(t)
            .adding {
                t.rotated(z: 90°).translated(x: 5)
            }

        let bounds = try await geometry.bounds
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 5)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 2)
    }

    @Test func `tag world anchor reflects tagged geometry's own transform`() async throws {
        // Tagged geometry was already translated by x:5 when tagged, so its world position is x:5..6.
        // The reference then translates that by an additional x:10 → x:15..16.
        let t = Tag()
        let geometry = Box(1)
            .translated(x: 5)
            .tagged(t)
            .adding {
                t.translated(x: 10)
            }

        let bounds = try await geometry.bounds
        #expect(bounds?.minimum ≈ [5, 0, 0])
        #expect(bounds?.maximum ≈ [16, 1, 1])
    }

    @Test func `outer transform around a tag reference is cancelled by world anchor`() async throws {
        // Wrapping the tag reference inside a group and translating the group should NOT move
        // the reference — the world anchor is preserved. Only direct chains on the tag/modified
        // reference move it.
        let t = Tag()
        let geometry = Box(1)
            .tagged(t)
            .adding {
                Union { t }.translated(x: 100)
            }

        let bounds = try await geometry.bounds
        #expect(bounds?.minimum ≈ [0, 0, 0])
        #expect(bounds?.maximum ≈ [1, 1, 1])
    }

    @Test func `tag translation applies in local frame of containing rotation`() async throws {
        // Tag captured at world (0..1, 0..1, 0..1). Inside a parent rotated by z:90°, the local +X
        // axis points along world +Y. So `.translated(x: 10)` on the reference should move it by
        // +10 in world Y, not in world X.
        let t = Tag()
        let geometry = Box(1)
            .tagged(t)
            .adding {
                Union { t.translated(x: 10) }.rotated(z: 90°)
            }

        let bounds = try await geometry.bounds
        #expect(bounds?.minimum.x ≈ 0)
        #expect(bounds?.maximum.x ≈ 1)
        #expect(bounds?.minimum.y ≈ 0)
        #expect(bounds?.maximum.y ≈ 11)
    }

    @Test func `outer transform around a modified tag reference is also cancelled`() async throws {
        // Same as above, but with a direct chain on the tag first. The direct chain should still
        // take effect; the outer group translate is cancelled.
        let t = Tag()
        let geometry = Box(1)
            .tagged(t)
            .adding {
                Union { t.translated(x: 10) }.translated(x: 100)
            }

        let bounds = try await geometry.bounds
        #expect(bounds?.minimum ≈ [0, 0, 0])
        #expect(bounds?.maximum ≈ [11, 1, 1])
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
