import XCTest
@testable import SwiftSCAD

final class Geometry3DTests: XCTestCase {
    func test3DBasics() {
        Box([20, 20, 20], center: .all)
            .intersection {
                Sphere(diameter: 23)
            }
            .subtracting {
                Cylinder(diameter: 2, height: 30)
                    .repeated(around: .x, in: 0°..<360°, count: 12)
                    .distributed(at: [0°, 90°], around: .z)
            }
        .assertEqual(toFile: "3dbasics")
    }
}
