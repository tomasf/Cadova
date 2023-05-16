import XCTest
@testable import SwiftSCAD

final class Geometry2DTests: XCTestCase {
    func test2DBasics() {
        Union {
            Rectangle(Vector2D(30, 10), center: .y)
                .subtracting {
                    Circle(diameter: 8)
                }
                .intersection {
                    Polygon([
                        [0, -10], [20, 2], [0, 10]
                    ])
                }
            Arc(range: 80°..<280°, radius: 3.5)
        }
        .assertEqual(toFile: "2dbasics")
    }

    func test2DMisc() {
        Rectangle(Vector2D(30, 10), center: .y)
            .subtracting {
                Circle(diameter: 8)
                    .scaled(x: 2)
                Arc(range: 20°..<160°, radius: 4)
                    .translated(x: 15)
                Teardrop(diameter: 5)
                    .translated(x: 22)
                Teardrop(diameter: 4, angle: 30°, style: .bridged)
                    .translated(x: 27)
            }
            .rounded(amount: 0.35, side: . both)
            .adding {
                RoundedRectangle([10, 10], bottomLeft: 5, bottomRight: 3, topRight: 2, topLeft: 0, center: .x)
                    .rotated(45°)
                    .translated(x: -3)

                Text("SwiftSCAD", font: .init(name: "Helvetica Neue", size: 10, style: "Bold"), alignment: (.left, .bottom), spacingFactor: 1.0)
                    .offset(amount: 0.4, style: .miter)
                    .translated(y: 5)
                    .sheared(.y, along: .x, angle: 20°)

                CylinderBridge(bottomDiameter: 10, topDiameter: 6)
                    .translated(x: 15)
                    .repeated(in: 20°..<250°, count: 5)
                    .translated(x: 50, y: -10)
            }
            .assertEqual(toFile: "2dmisc")
    }
}
