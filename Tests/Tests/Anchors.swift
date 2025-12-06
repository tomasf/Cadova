import Testing
@testable import Cadova

struct AnchorTests {
    @Test func anchor() async throws {
        let boxRightSide = Anchor("right side of box")

        let geometry = Stack(.z, alignment: .center) {
            Box(4)
                .colored(.green)
            Box(10)
                .colored(.blue)
                .definingAnchor(boxRightSide, at: .center, .right, pointing: .right)
        }.adding {
            Cylinder(diameter: 1, height: 10)
                .colored(.red)
                .anchored(to: boxRightSide)
        }

        try await geometry.expectEquals(goldenFile: "anchors/anchor")
        #expect(try await geometry.bounds ≈ .init(minimum: [-5, -5, 0], maximum: [15, 5, 14]))
    }

    @Test func multipleDefinitions() async throws {
        let sphereSurface = Anchor("sphere's surface")

        let geometry = Box(1)
            .aligned(at: .centerXY)
            .adding {
                Sphere(diameter: 4)
                    .definingAnchor(sphereSurface, at: .right, pointing: .right)
                    .definingAnchor(sphereSurface, at: .top, pointing: .up)
                    .definingAnchor(sphereSurface, at: .back, pointing: .forward)
                    .aligned(at: .bottom)
                    .translated(z: 1)
            }
            .aligned(at: .min)
            .adding {
                Cylinder(diameter: 1, height: 10)
                    .anchored(to: sphereSurface)
            }

        try await geometry.expectEquals(goldenFile: "anchors/multiple")
        #expect(try await geometry.bounds ≈ .init(minimum: .zero, maximum: [14, 14, 15]))
    }

    @Test func usedBeforeDefinition() async throws {
        let rightAnchor = Anchor("sphere's right side")

        let geometry = Box(1)
            .aligned(at: .centerXY)
            .adding {
                Cylinder(diameter: 1, height: 10)
                    .anchored(to: rightAnchor)
            }
            .aligned(at: .min)
            .adding {
                Sphere(diameter: 4)
                    .definingAnchor(rightAnchor, at: .right, pointing: .right)
                    .aligned(at: .bottom)
                    .translated(z: 1)
            }

        try await geometry.expectEquals(goldenFile: "anchors/usedBeforeDefinition")
        #expect(try await geometry.bounds ≈ .init(minimum: [-2, -2, 0], maximum: [12, 2, 5]))
    }

    @Test func alignedAt() async throws {
        let boxRightSide = Anchor("right side of box")

        let geometry = Stack(.z, alignment: .center) {
            Box(4)
                .colored(.green)
            Box(10)
                .colored(.blue)
                .definingAnchor(boxRightSide, at: .center, .right, pointing: .right)
        }.aligned(at: boxRightSide)

        try await geometry.expectEquals(goldenFile: "anchors/alignedAt")
        #expect(try await geometry.bounds ≈ .init(minimum: [-5, -5, -10], maximum: [9, 5, 0]))
    }
}
