import Foundation
import Testing
@testable import Cadova

struct LoftTests {
    @Test func threeLayers() async throws {
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

        let m = try await loft.measurements

        #expect(m.volume ≈ 7846.93)
        #expect(m.surfaceArea ≈ 3980.143)
        #expect(m.boundingBox ≈ .init(minimum: [-12.5, -12.5, 0], maximum: [12.5, 12.5, 35]))
    }

    @Test func layerSpecificShaping() async throws {
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

        try await loft.writeVerificationModel(name: "layerSpecificShaping")
        let m = try await loft.measurements

        #expect(m.volume ≈ 3864.051)
        #expect(m.surfaceArea ≈ 1236.991)
        #expect(m.boundingBox ≈ .init(minimum: [-9.998, -9.998, 0], maximum: [9.999, 9.999, 20]))
    }

    @Test func layerSpecificShapingWithDefault() async throws {
        let loft = Loft(.resampled(.smoothstep)) {
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

        try await loft.writeVerificationModel(name: "layerSpecificShapingWithDefault")
        let m = try await loft.measurements

        #expect(m.volume ≈ 2732.414)
        #expect(m.surfaceArea ≈ 1118.009)
        #expect(m.boundingBox ≈ .init(minimum: [-9.999, -9.998, 0], maximum: [9.999, 9.998, 20]))
    }
}

