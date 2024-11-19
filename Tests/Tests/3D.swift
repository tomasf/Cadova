import Foundation
import Testing
@testable import SwiftSCAD

struct Geometry3DTests {
    @Test func basic3D() {
        Box([20, 20, 20])
            .aligned(at: .center)
            .intersecting {
                Sphere(diameter: 23)
            }
            .subtracting {
                Cylinder(diameter: 2, height: 30)
                    .repeated(around: .x, in: 0°..<360°, count: 12)
                    .distributed(at: [0°, 90°], around: .z)
            }
            .expectCodeEquals(file: "3d/basics")
    }

    @Test func empty3D() {
         Box([10, 20, 30])
            .subtracting {}
            .adding {}
            .expectCodeEquals(file: "3d/empty")
    }

    @Test func roundedBoxes() {
        Stack(.x, spacing: 1) {
            Box([10, 8, 5])
                .roundingBoxCorners(radius: 2)
            Box([10, 8, 5])
                .roundingBoxCorners(radius: 2)
                .usingFacets(count: 20)
            Box([3, 4, 18])
                .roundingBoxCorners(.topRight, axis: .x, radius: 2)
            Box([8, 10, 6])
                .roundingBoxCorners(.bottom, axis: .y, radius: 2.5)
        }
        .expectCodeEquals(file: "3d/rounded-box")
    }

    @Test func cylinders() {
        Stack(.y, spacing: 1) {
            Cylinder(bottomRadius: 3, topRadius: 6, height: 10)
            Cylinder(largerDiameter: 10, apexAngle: 10°, height: 20)
            Cylinder(largerDiameter: 20, apexAngle: -30°, height: 25)
            Cylinder(smallerDiameter: 8, apexAngle: 60°, height: 10)
            Cylinder(bottomDiameter: 10, topDiameter: 20, apexAngle: 20°)
        }
        .expectCodeEquals(file: "3d/cylinders")
    }
}
