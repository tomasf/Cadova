import Testing
@testable import Cadova

struct BoundsTests {
    @Test func basicAlignment2D() async {
        let geometry = Rectangle([10, 4])
            .aligned(at: .centerX, .top)

        #expect(await geometry.bounds ≈ .init(minimum: [-5, -4], maximum: [5, 0]))
    }

    @Test func conflictingAlignment() async {
        let geometry = Rectangle([50, 20])
            .aligned(at: .minX, .centerX, .centerY, .maxX)

        #expect(await geometry.bounds ≈ .init(minimum: [-50, -10], maximum: [0, 10]))
    }

    @Test func repeatedAlignment() async {
       let geometry = Box([10, 8, 12])
            .aligned(at: .minX)
            .aligned(at: .maxY)
            .aligned(at: .centerX, .centerY)
            .aligned(at: .maxX)
            .aligned(at: .centerXY)

        #expect(await geometry.bounds ≈ .init(minimum: [-5, -4, 0], maximum: [5, 4, 12]))
    }

    @Test func transformedBounds() async {
        let base = Box([10, 8, 12])
            .rotated(x: 90°)
            .translated(y: 12)

        let extended = base
            .scaled(z: 1.25)
            .sheared(.x, along: .y, factor: 1.5)

        #expect(await base.bounds ≈ Box([10, 12, 8]).bounds)
        #expect(await extended.bounds ≈ .init(minimum: .zero, maximum: [28, 12, 10]))
    }

    @Test func stack() async {
        let geometry = Stack(.x, spacing: 1) {
            Box([10, 8, 12])
            RegularPolygon(sideCount: 8, apothem: 3)
                .rotated(22.5°)
                .extruded(height: 1)
            Rectangle([2, 5])
                .scaled(x: 2)
                .extruded(height: 3)
        }

        #expect(await geometry.bounds ≈ .init(minimum: .zero, maximum: [22, 8, 12]))
    }

    @Test func anchors() async {
        let top = Anchor()
        let side = Anchor()
        let base = Box([8,6,4])
            .aligned(at: .centerXY, .top)
            .adding {
                Box([2,2,1])
                    .aligned(at: .centerXY)
                    .definingAnchor(top, at: .top)
            }
            .definingAnchor(side, at: .left, offset: [0, 0, -2], pointing: .left)
            .anchored(to: top)
            .anchored(to: side)

        let extended = base.anchored(to: top)

        #expect(await base.bounds ≈ .init(minimum: [-2, -3, -8], maximum: [3, 3, 0]))
        #expect(await extended.bounds ≈ .init(minimum: [-4, -3, -5], maximum: [4, 3, 0]))
    }
}
