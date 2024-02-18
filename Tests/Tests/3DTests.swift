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

        Box([10, 20, 30])
            .subtracting {}
            .adding {}
            .assertEqual(toFile: "empty3d")
    }

    func testOperations() {
        let testGeometry = Box([1,2,3])
            .assertOperation(.addition)
            .subtracting {
                Sphere(diameter: 3)
                    .assertOperation(.subtraction)
                    .subtracting {
                        Box([1,2,3])
                            .assertOperation(.addition)
                    }
                    .assertOperation(.subtraction)
            }
            .assertOperation(.addition)

        _ = testGeometry
            .scadString(in: .defaultEnvironment)
    }
}

extension Geometry3D {
    func assertOperation(_ expectedOperation: Environment.Operation) -> any Geometry3D {
        readingEnvironment { geo, environment in
            XCTAssertEqual(environment.operation, expectedOperation)
            geo
        }
    }
}
