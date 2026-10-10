import Cadova

await Project {
    await Model("plate") {
        Metadata(title: "Test Plate", description: "A plate for testing the web customizer.")
        Plate()
    }
}

enum Corners: String, CaseIterable, ParameterValue {
    case square, rounded
}

struct Plate: Geometry3D {
    @Parameter("width", in: 10...100, step: 1, description: "Width in millimeters")
    var width = 40.0

    @Parameter("holes", in: 0...4, description: "Number of holes along the middle")
    var holes = 2

    @Parameter("thick", description: "Make the plate 6 mm thick instead of 3")
    var thick = false

    @Parameter("corners", description: "Corner style")
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
