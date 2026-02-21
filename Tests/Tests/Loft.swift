import Foundation
import Testing
@testable import Cadova

struct LoftTests {
    @Test func `loft with three layers and holes produces correct geometry`() async throws {
        let loft = Loft {
            layer(z: 0) {
                Circle(diameter: 20)
                    .subtracting {
                        Circle(diameter: 12)
                    }
            }
            layer(z: 30) {
                Rectangle(x: 25, y: 6)
                    .aligned(at: .center)
                    .repeated(in: 0°..<180°, count: 2)
                    .subtracting {
                        RegularPolygon(sideCount: 8, circumradius: 2)
                    }
            }
            layer(z: 35) {
                Circle(diameter: 12)
                    .subtracting {
                        Circle(diameter: 10)
                    }
            }
        }

        try await loft.writeVerificationModel(name: "loftThreeLayers")
        let m = try await loft.measurements

        #expect(m.volume ≈ 7853.615)
        #expect(m.surfaceArea ≈ 3791.857)
        #expect(m.boundingBox ≈ .init(minimum: [-12.5, -12.5, 0], maximum: [12.5, 12.5, 35]))
    }

    @Test func `layer can specify custom shaping function`() async throws {
        let loft = Loft {
            layer(z: 0) {
                Circle(diameter: 5)
            }
            layer(z: 5) {
                Circle(diameter: 12)
            }
            layer(z: 15, interpolation: .circularEaseOut) {
                Circle(diameter: 20)
            }
            layer(z: 20) {
                Circle(diameter: 10)
            }
        }

        try await loft.writeVerificationModel(name: "loftLayerSpecificShaping")
        let m = try await loft.measurements

        #expect(m.volume ≈ 3864.051)
        #expect(m.surfaceArea ≈ 1236.991)
        #expect(m.boundingBox?.equals(.init(minimum: [-10, -10, 0], maximum: [10, 10, 20]), within: 1e-2) == true)
    }

    @Test func `layer shaping overrides loft default shaping`() async throws {
        let loft = Loft(interpolation: .smoothstep) {
            layer(z: 0) {
                Circle(diameter: 5)
            }
            layer(z: 5, interpolation: .linear) {
                Circle(diameter: 12)
            }
            layer(z: 15, interpolation: .circularEaseIn) {
                Circle(diameter: 20)
            }
            layer(z: 20) {
                Circle(diameter: 10)
            }
        }

        try await loft.writeVerificationModel(name: "loftLayerSpecificShapingWithDefault")
        let m = try await loft.measurements

        #expect(m.volume ≈ 2732.414)
        #expect(m.surfaceArea ≈ 1118.009)
        #expect(m.boundingBox?.equals(.init(minimum: [-10, -10, 0], maximum: [10, 10, 20]), within: 1e-2) == true)
    }

    @Test func `convex hull transition creates hull between layers`() async throws {
        let loft = Loft {
            layer(z: 0) {
                Circle(diameter: 20)
            }
            layer(z: 10, interpolation: .convexHull) {
                Rectangle([10, 10])
                    .aligned(at: .center)
            }
        }

        try await loft.writeVerificationModel(name: "loftConvexHull")
        let m = try await loft.measurements

        // The convex hull of a circle at z=0 and a square at z=10
        // should produce a solid that's larger than a simple loft
        #expect(m.volume > 0)
        #expect(m.surfaceArea > 0)
        #expect(m.boundingBox ≈ .init(minimum: [-10, -10, 0], maximum: [10, 10, 10]))
    }

    @Test func `mixed interpolation and convex hull transitions work together`() async throws {
        let loft = Loft {
            layer(z: 0) {
                Circle(diameter: 10)
            }
            layer(z: 10) {
                Circle(diameter: 20)
            }
            layer(z: 20, interpolation: .convexHull) {
                Rectangle([8, 8])
                    .aligned(at: .center)
            }
            layer(z: 30) {
                Rectangle([15, 15])
                    .aligned(at: .center)
            }
        }

        try await loft.writeVerificationModel(name: "loftMixedTransitions")
        let m = try await loft.measurements

        #expect(m.volume > 0)
        #expect(m.surfaceArea > 0)
        // Bounding box should span from the circle at bottom to rectangle at top
        #expect(m.boundingBox ≈ .init(minimum: [-10, -10, 0], maximum: [10, 10, 30]))
    }

    @Test func `linear loft between similar triangles preserves corners`() async throws {
        let loft = Loft(interpolation: .linear) {
            layer(z: 0) {
                Triangle(a: 2, b: 2, includedGamma: 90°)
            }
            layer(z: 30) {
                Triangle(a: 5, b: 5, includedGamma: 90°)
            }
        }

        try await loft.writeVerificationModel(name: "loftLinearTriangles")
        let m = try await loft.measurements

        #expect(m.volume > 0)
        #expect(m.surfaceArea > 0)
        // With corners preserved, the loft reaches exactly to the outer vertices of the top triangle
        #expect(m.boundingBox ≈ .init(minimum: [0, 0, 0], maximum: [5, 5, 30]))
    }

    @Test func `loft between rectangles preserves corners`() async throws {
        let loft = Loft(interpolation: .linear) {
            layer(z: 0) {
                Rectangle([4, 6]).aligned(at: .center)
            }
            layer(z: 20) {
                Rectangle([10, 8]).aligned(at: .center)
            }
        }

        try await loft.writeVerificationModel(name: "loftRectangles")
        let m = try await loft.measurements

        #expect(m.volume > 0)
        #expect(m.surfaceArea > 0)
        // Corners of the top rectangle are at exactly ±5 and ±4
        #expect(m.boundingBox ≈ .init(minimum: [-5, -4, 0], maximum: [5, 4, 20]))
    }

    @Test func `loft from circle to triangle produces valid geometry`() async throws {
        let loft = Loft(interpolation: .linear) {
            layer(z: 0) {
                Circle(diameter: 10)
            }
            layer(z: 20) {
                Triangle(a: 8, b: 8, includedGamma: 90°)
            }
        }

        try await loft.writeVerificationModel(name: "loftCircleToTriangle")
        let m = try await loft.measurements

        #expect(m.volume > 0)
        #expect(m.surfaceArea > 0)
    }

    // MARK: - Layer resolution

    @Test func `absolute layers resolve to correct Z positions`() {
        let loft = Loft {
            layer(z: 0) { Circle(diameter: 5) }
            layer(z: 10) { Circle(diameter: 5) }
            layer(z: 25) { Circle(diameter: 5) }
        }
        #expect(loft.layers.map(\.z) == [0, 10, 25])
    }

    @Test func `offset layers resolve relative to previous layer`() {
        let loft = Loft {
            layer(z: 0) { Circle(diameter: 5) }
            layer(zOffset: 10) { Circle(diameter: 5) }
            layer(zOffset: 5) { Circle(diameter: 5) }
        }
        #expect(loft.layers.map(\.z) == [0, 10, 15])
    }

    @Test func `absolute range creates two layers at bounds`() {
        let loft = Loft {
            layer(z: 0) { Circle(diameter: 5) }
            layer(z: 5..<15) { Circle(diameter: 5) }
            layer(z: 20) { Circle(diameter: 5) }
        }
        #expect(loft.layers.map(\.z) == [0, 5, 15, 20])
    }

    @Test func `offset range creates two layers relative to previous`() {
        let loft = Loft {
            layer(z: 0) { Circle(diameter: 5) }
            layer(zOffset: 5..<15) { Circle(diameter: 5) }
            layer(zOffset: 3) { Circle(diameter: 5) }
        }
        #expect(loft.layers.map(\.z) == [0, 5, 15, 18])
    }

    @Test func `mixed absolute and offset layers resolve correctly`() {
        let loft = Loft {
            layer(z: 0) { Circle(diameter: 5) }
            layer(zOffset: 10) { Circle(diameter: 5) }
            layer(z: 30) { Circle(diameter: 5) }
            layer(zOffset: 5) { Circle(diameter: 5) }
        }
        #expect(loft.layers.map(\.z) == [0, 10, 30, 35])
    }

    @Test func `out-of-order absolute layers are sorted by Z`() {
        let loft = Loft {
            layer(z: 20) { Circle(diameter: 5) }
            layer(z: 0) { Circle(diameter: 5) }
            layer(z: 10) { Circle(diameter: 5) }
        }
        #expect(loft.layers.map(\.z) == [0, 10, 20])
    }

    @Test func `offset after absolute range starts from range upper bound`() {
        let loft = Loft {
            layer(z: 0) { Circle(diameter: 5) }
            layer(z: 10..<20) { Circle(diameter: 5) }
            layer(zOffset: 5) { Circle(diameter: 5) }
        }
        #expect(loft.layers.map(\.z) == [0, 10, 20, 25])
    }

    @Test func `offset after offset range starts from range upper bound`() {
        let loft = Loft {
            layer(z: 0) { Circle(diameter: 5) }
            layer(zOffset: 10..<20) { Circle(diameter: 5) }
            layer(zOffset: 5) { Circle(diameter: 5) }
        }
        #expect(loft.layers.map(\.z) == [0, 10, 20, 25])
    }

    // MARK: - Geometry

    @Test func `visualized loft shows layers at correct positions`() async throws {
        let loft = Loft {
            layer(z: 0) {
                Circle(diameter: 20)
            }
            layer(z: 10) {
                Rectangle([15, 15])
                    .aligned(at: .center)
            }
            layer(z: 25) {
                Circle(diameter: 10)
            }
        }

        let visualization = loft.visualized()
        try await visualization.writeVerificationModel(name: "loftVisualized")
        let m = try await visualization.measurements(for: .allParts)

        // The visualization should span approximately from z=0 to z=25
        #expect(m.boundingBox!.minimum.z ≈ 0)
        #expect(m.boundingBox!.maximum.z ≈ 25)
        // Should have some volume (the extruded layer slabs)
        #expect(m.volume > 0)
    }
}

