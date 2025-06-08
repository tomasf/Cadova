import Testing
@testable import Cadova

struct Geometry2DTests {
    @Test func basic2D() async throws {
        try await Union {
            Rectangle(Vector2D(30, 10))
                .aligned(at: .centerY)
                .subtracting {
                    Circle(diameter: 8)
                }
                .intersecting {
                    Polygon([
                        [0, -10], [20, 2], [0, 10]
                    ])
                }
            Arc(range: 80°..<280°, radius: 3.5)
        }
        .expectEquals(goldenFile: "2d/basics")
    }

    @Test func circular() async throws {
        try await Union {
            Circle(diameter: 8)
                .scaled(x: 2)
            Arc(range: 20°..<160°, radius: 4)
                .translated(x: 15)
            Teardrop(diameter: 5)
                .translated(x: 22)
            Teardrop(diameter: 4, style: .flat)
                .withOverhangAngle(30°)
                .translated(x: 27)
            CylinderBridge(bottomDiameter: 10, topDiameter: 6)
                .translated(x: 15)
                .repeated(in: 20°..<250°, count: 5)
                .translated(x: 50, y: -10)
        }
        .expectEquals(goldenFile: "2d/circular")
    }

    @Test func roundedRectangle() async throws {
        try await Rectangle(x: 10, y: 10)
            .applyingEdgeProfile(.fillet(radius: 5), to: .bottomLeft)
            .applyingEdgeProfile(.fillet(radius: 3), to: .bottomRight)
            .applyingEdgeProfile(.fillet(radius: 2), to: .topRight)
            .aligned(at: .centerX)
            .rotated(45°)
            .translated(x: -3)
            .expectEquals(goldenFile: "2d/rounded-rectangle")
    }
}
