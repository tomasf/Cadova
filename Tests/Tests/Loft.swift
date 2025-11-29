import Foundation
import Testing
@testable import Cadova

struct LoftTests {
    @Test func threeLayers() async throws {
        let loft = Loft {
            layer(at: 0) {
                Circle(diameter: 20)
                    .subtracting {
                        Circle(diameter: 12)
                    }
            }
            layer(at: 30) {
                Rectangle(x: 25, y: 6)
                    .aligned(at: .center)
                    .repeated(in: 0°..<180°, count: 2)
                    .subtracting {
                        RegularPolygon(sideCount: 8, circumradius: 2)
                    }
            }
            layer(at: 35) {
                Circle(diameter: 12)
                    .subtracting {
                        Circle(diameter: 10)
                    }
            }
        }

        try await loft.writeVerificationModel(name: "loftThreeLayers")
        let m = try await loft.measurements

        #expect(m.volume ≈ 7846.995)
        #expect(m.surfaceArea ≈ 3786.088)
        #expect(m.boundingBox ≈ .init(minimum: [-12.5, -12.5, 0], maximum: [12.5, 12.5, 35]))
    }

    @Test func layerSpecificShaping() async throws {
        let loft = Loft {
            layer(at: 0) {
                Circle(diameter: 5)
            }
            layer(at: 5) {
                Circle(diameter: 12)
            }
            layer(at: 15, interpolation: .circularEaseOut) {
                Circle(diameter: 20)
            }
            layer(at: 20) {
                Circle(diameter: 10)
            }
        }

        try await loft.writeVerificationModel(name: "loftLayerSpecificShaping")
        let m = try await loft.measurements

        #expect(m.volume ≈ 3864.051)
        #expect(m.surfaceArea ≈ 1236.991)
        #expect(m.boundingBox?.equals(.init(minimum: [-10, -10, 0], maximum: [10, 10, 20]), within: 1e-2) == true)
    }

    @Test func layerSpecificShapingWithDefault() async throws {
        let loft = Loft(interpolation: .smoothstep) {
            layer(at: 0) {
                Circle(diameter: 5)
            }
            layer(at: 5, interpolation: .linear) {
                Circle(diameter: 12)
            }
            layer(at: 15, interpolation: .circularEaseIn) {
                Circle(diameter: 20)
            }
            layer(at: 20) {
                Circle(diameter: 10)
            }
        }

        try await loft.writeVerificationModel(name: "loftLayerSpecificShapingWithDefault")
        let m = try await loft.measurements

        #expect(m.volume ≈ 2732.414)
        #expect(m.surfaceArea ≈ 1118.009)
        #expect(m.boundingBox?.equals(.init(minimum: [-10, -10, 0], maximum: [10, 10, 20]), within: 1e-2) == true)
    }
}

