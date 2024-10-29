import Foundation
import Testing
@testable import SwiftSCAD

struct Geometry3DTests {
    @Test func basic3D() {
        let geometry = Box([20, 20, 20])
            .aligned(at: .center)
            .intersection {
                Sphere(diameter: 23)
            }
            .subtracting {
                Cylinder(diameter: 2, height: 30)
                    .repeated(around: .x, in: 0°..<360°, count: 12)
                    .distributed(at: [0°, 90°], around: .z)
            }

        #expect(geometry.code == scadFile("3dbasics"))
    }

    @Test func empty3D() {
        let geometry = Box([10, 20, 30])
            .subtracting {}
            .adding {}

        #expect(geometry.code == scadFile("empty3d"))
    }

    @Test func roundedBoxes() {
        let geometry = Stack(.x, spacing: 1) {
            Box([10, 8, 5])
                .roundingBoxCorners(radius: 2)
            Box([10, 8, 5])
                .roundingBoxCorners(radius: 2)
                .usingFacets(count: 20)
        }

        #expect(geometry.code == scadFile("rounded-box"))
    }

    @Test func cylinders() {
        let geometry = Stack(.y, spacing: 1) {
            Cylinder(bottomRadius: 3, topRadius: 6, height: 10)
            Cylinder(largerDiameter: 10, apexAngle: 10°, height: 20)
            Cylinder(largerDiameter: 20, apexAngle: -30°, height: 25)
            Cylinder(smallerDiameter: 8, apexAngle: 60°, height: 10)
            Cylinder(bottomDiameter: 10, topDiameter: 20, apexAngle: 20°)
        }

        #expect(geometry.code == scadFile("cylinders"))
    }
}
