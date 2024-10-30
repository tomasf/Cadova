import Testing
@testable import SwiftSCAD

struct ExampleTests {
    @Test func example1(){
        let geometry = Box([10, 20, 5])
            .aligned(at: .centerY)
            .rotated(y: -20°, z: 45°)

        #expect(geometry.code == scadFile("example1"))
    }

    @Test func example2() {
        let geometry = Circle(diameter: 10)
            .usingFacets(count: 3)
            .translated(x: 2)
            .scaled(x: 2)
            .repeated(in: 0°..<360°, count: 5)
            .rounded(amount: 1)
            .extruded(height: 5, twist: -20°)
            .subtracting {
                Cylinder(bottomDiameter: 1, topDiameter: 5, height: 20)
                    .translated(y: 2, z: -7)
                    .rotated(x: 20°)
                    .highlighted()
            }

        #expect(geometry.code == scadFile("example2"))
    }

    struct Star: Shape2D {
        let pointCount: Int
        let radius: Double
        let pointRadius: Double
        let centerSize: Double

        var body: any Geometry2D {
            Circle(diameter: centerSize)
                .adding {
                    Circle(radius: max(pointRadius, 0.001))
                        .translated(x: radius)
                }
            .convexHull()
            .repeated(in: 0°..<360°, count: pointCount)
        }
    }

    @Test func example3() {
        let geometry = Stack(.x, spacing: 1, alignment: .centerY) {
            Star(pointCount: 5, radius: 10, pointRadius: 1, centerSize: 4)
            Star(pointCount: 6, radius: 8, pointRadius: 0, centerSize: 2)
        }

        #expect(geometry.code == scadFile("example3"))
    }

    @Test func example4() {
        let path = BezierPath2D(startPoint: .zero)
            .addingCubicCurve(controlPoint1: [10, 65], controlPoint2: [55, -20], end: [60, 40])

        let geometry = Star(pointCount: 5, radius: 10, pointRadius: 1, centerSize: 4)
            .usingDefaultFacets()
            .extruded(along: path)
            .withPreviewConvexity(4)
            .usingFacets(minAngle: 5°, minSize: 1)

        #expect(geometry.code == scadFile("example4"))
    }
}
