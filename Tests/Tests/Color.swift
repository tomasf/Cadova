import Foundation
import Testing
import SwiftSCAD

struct ColorTests {
    // A tree wrapped in a color modifier declares its colors directly
    // around its leaves. If we wrap the entire tree, outer declarations
    // would override inner ones. Also, we need to re-declare directly
    // around extrusions, projections.

    @Test func colors() {
        let geometry = Rectangle(10) // Declaration here (red)
            .translated(x: 2)
            .adding {
                Circle(radius: 3) // Declaration here (blue). But because we're inside of an extrusion, no blue is actually shown.
                    .colored(.blue)
            }
            .extruded(height: 3) // Declaration here (red)
            .adding {
                Cylinder(diameter: 2, height: 20) // Declaration here (red)
                    .scaled(0.8)
                    .subtracting {
                        Cylinder(diameter: 3, height: 4) // Declaration here (red)
                    }
                    .adding {
                        Sphere(diameter: 4) // Declaration here (green)
                            .translated(z: 16)
                            .colored(.green)
                    }
            }
            .colored(.red)
            .adding {
                Sphere(diameter: 3)
            }

        #expect(geometry.code == scadFile("colors"))
    }
}
