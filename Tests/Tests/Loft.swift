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
}

