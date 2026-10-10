import Cadova

await Project {
    Metadata(title: "Test Parts", description: "Parts for testing the web customizer.")

    await Model("plate") {
        Metadata(title: "Test Plate", description: "A plate with holes.")
        Plate()
    }

    // Has a parameter with the same label as one of the plate's, which is still its own, and no
    // title of its own
    await Model("spacer") {
        @Parameter("Width", in: 10...60, step: 1, description: "Diameter in millimeters")
        var width = 20.0

        @Parameter("Height", in: 1...20, step: 1, description: "Height in millimeters")
        var height = 5.0

        Cylinder(diameter: width, height: height)
    }
}

enum Corners: String, CaseIterable, ParameterValue {
    case square, rounded
}

struct Plate: Geometry3D {
    @Parameter("Width", in: 10...100, step: 1, description: "Width in millimeters")
    var width = 40.0

    @Parameter("Holes", in: 0...4, description: "Number of holes along the middle")
    var holes = 2

    @Parameter("Thick", description: "Make the plate 6 mm thick instead of 3")
    var thick = false

    @Parameter("Corners", description: "Corner style")
    var corners = Corners.rounded

    var body: any Geometry3D {
        let plate = Rectangle(x: width, y: 30).aligned(at: .center)
        let outline: any Geometry2D = corners == .rounded ? plate.rounded(radius: 3) : plate

        outline
            .subtracting {
                (0..<holes).mapUnion { index in
                    Circle(radius: 2).translated(x: (Double(index) - Double(holes - 1) / 2) * 8)
                }
            }
            .extruded(height: thick ? 6 : 3)
    }
}
