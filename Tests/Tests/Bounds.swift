import XCTest
@testable import SwiftSCAD

final class BoundsTests: XCTestCase {
    func testBasic2DAlignment() {
        Rectangle([10, 4])
            .aligned(at: .centerX, .top)
            .assertBoundsEqual(min: [-5, -4], max: [5, 0])
    }

    func testConflictingAlignment() {
        Rectangle([50, 20])
            .aligned(at: .minX, .centerX, .centerY, .maxX)
            .assertBoundsEqual(min: [-50, -10], max: [0, 10])
    }

    func testRepeatedAlignment() {
        Box([10, 8, 12])
            .aligned(at: .minX)
            .aligned(at: .maxY)
            .aligned(at: .centerX, .centerY)
            .aligned(at: .maxX)
            .aligned(at: .centerXY)
            .assertBoundsEqual(min: [-5, -4, 0], max: [5, 4, 12])
    }

    func testTransformedBounds() {
        Box([10, 8, 12])
            .rotated(x: 90°)
            .translated(y: 12)
            .assertBoundsEqual {
                Box([10, 12, 8])
            }
            .scaled(z: 1.25)
            .sheared(.x, along: .y, factor: 1.5)
            .assertBoundsEqual(min: [0, 0, 0], max: [28, 12, 10])
    }

    func testStack() {
        Stack(.x, spacing: 1) {
            Box([10, 8, 12])
            RegularPolygon(sideCount: 8, apothem: 3)
                .rotated(22.5°)
                .extruded(height: 1)
            Rectangle([2, 5])
                .scaled(x: 2)
                .extruded(height: 3)
        }
        .assertBoundsEqual(min: [0, 0, 0], max: [22, 8, 12])
    }

    func testAnchors() {
        let top = Anchor()
        let side = Anchor()
        Box([8,6,4])
            .aligned(at: .centerXY, .top)
            .adding {
                Box([2,2,1])
                    .aligned(at: .centerXY)
                    .definingAnchor(top, at: .top)
                side.define()
                    .rotated(y: -90°)
                    .translated(x: -4, z: -2)
            }
            .anchored(to: top)
            .anchored(to: side)
            .assertBoundsEqual(min: [-2, -3, -8], max: [3, 3, 0])
            .anchored(to: top)
            .assertBoundsEqual(min: [-4, -3, -5], max: [4, 3, 0])
    }
}
