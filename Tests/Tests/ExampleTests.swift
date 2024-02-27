import XCTest
@testable import SwiftSCAD

final class ExampleTests: XCTestCase {
    func testExample1() throws {
        Box([10, 20, 5], center: .y)
            .rotated(y: -20°, z: 45°)
            .assertEqual(toFile: "example1")
    }

    func testExample2() throws {
        Circle(diameter: 10)
            .usingFacets(count: 3)
            .translated(x: 2)
            .scaled(x: 2)
            .repeated(in: 0°..<360°, count: 5)
            .rounded(amount: 1)
            .extruded(height: 5, twist: 20°, slices: 20)
            .subtracting {
                Cylinder(bottomDiameter: 1, topDiameter: 5, height: 20)
                    .translated(y: 2, z: -7)
                    .rotated(x: 20°)
                    .highlighted()
            }
            .assertEqual(toFile: "example2")
    }

    struct Star: Shape2D {
        let pointCount: Int
        let radius: Double
        let pointRadius: Double
        let centerSize: Double

        var body: any Geometry2D {
            Union {
                Circle(diameter: centerSize)
                Circle(radius: max(pointRadius, 0.001))
                    .translated(x: radius)
            }
            .convexHull()
            .repeated(in: 0°..<360°, count: pointCount)
        }
    }

    func testExample3() throws {
        Union {
            Star(pointCount: 5, radius: 10, pointRadius: 1, centerSize: 4)
            Star(pointCount: 6, radius: 8, pointRadius: 0, centerSize: 2)
                .translated(x: 20)
        }
        .assertEqual(toFile: "example3")
    }

    func testExample4() throws {
        let path = BezierPath2D(startPoint: .zero)
            .addingCubicCurve(controlPoint1: [10, 65], controlPoint2: [55, -20], end: [60, 40])

        Star(pointCount: 5, radius: 10, pointRadius: 1, centerSize: 4)
            .usingDefaultFacets()
            .extruded(along: path, radius: 11)
            .usingFacets(minAngle: 5°, minSize: 1)
            .assertEqual(toFile: "example4")
    }
}
