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
}
