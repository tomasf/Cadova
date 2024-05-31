import XCTest
@testable import SwiftSCAD

final class Geometry2DTests: XCTestCase {
    func test2DBasics() {
        Union {
            Rectangle(Vector2D(30, 10))
                .aligned(at: .centerY)
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
        Rectangle(Vector2D(30, 10))
            .aligned(at: .centerY)
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
                Rectangle(x: 10, y: 10)
                    .roundingRectangleCorners(.bottomLeft, radius: 5)
                    .roundingRectangleCorners(.bottomRight, radius: 3)
                    .roundingRectangleCorners(.topRight, radius: 2)
                    .aligned(at: .centerX)
                    .rotated(45°)
                    .translated(x: -3)

                Text("SwiftSCAD")
                    .usingFont("Helvetica", size: 14)
                    .usingTextAlignment(horizontal: .left, vertical: .bottom)
                    .offset(amount: 0.4, style: .miter)
                    .translated(y: 5)
                    .sheared(.y, angle: 20°)

                CylinderBridge(bottomDiameter: 10, topDiameter: 6)
                    .translated(x: 15)
                    .repeated(in: 20°..<250°, count: 5)
                    .translated(x: 50, y: -10)
            }
            .assertEqual(toFile: "2dmisc")
    }
}
