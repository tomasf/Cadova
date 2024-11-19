import Testing
@testable import SwiftSCAD

struct StackTests {
    @Test func stackZ() {
        // The Z part of the alignment should be ignored
        Stack(.z, alignment: .center) {
            Cylinder(diameter: 1, height: 1)
            Cylinder(bottomDiameter: 0, topDiameter: 3, height: 1)
            Cylinder(diameter: 3, height: 2)
        }
        .expectCodeEquals(file: "zstack")
    }
}
