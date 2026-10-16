import Cadova
import Foundation

await Project {
    Metadata(title: "Test Parts", description: "Parts for testing the web customizer.", author: "Test Author", license: "MIT")

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

        // A color to choose, to test the color picker
        @Parameter("Color") var color = Color(red: 0.2, green: 0.4, blue: 0.8)

        // A material, to test that the viewer shows it
        Cylinder(diameter: width, height: height)
            .withMaterial(color: color, metallicness: 0.5, roughness: 0.3)
    }

    // In a group, which a customizer's menu lists it under
    await Group("extras") {
        await Model("washer") {
            @Parameter("Diameter", in: 5...30, step: 1, unit: "mm") var diameter = 12.0
            // A description of several lines with a link, which depends on a parameter, and a
            // license of its own
            Metadata(
                title: "Washer",
                description: "A washer \(Int(diameter)) mm across.\nMore at https://example.com/washers.",
                license: "CC0"
            )
            Circle(diameter: diameter)
                .subtracting { Circle(diameter: diameter / 2) }
                .extruded(height: 1.5)
        }

        // Named like the spacer above, and without a title, so its tab has to name its group
        await Model("spacer") {
            @Parameter("Size", in: 5...30, step: 1, unit: "mm") var size = 10.0
            Box(size)
        }
    }
}

enum Corners: String, ParameterChoice {
    case square, rounded
}

struct Plate: Geometry3D {
    @Parameter("Width", in: 10...100, step: 1, unit: "mm", description: "Width of the plate")
    var width = 40.0

    @Parameter("Thick", description: "Make the plate 6 mm thick instead of 3")
    var thick = false

    @Parameter("Corners", description: "Corner style")
    var corners = Corners.rounded

    // Read from a resource, to test that a customizer has the package's resources
    static let depth: Double = {
        let url = Bundle.module.url(forResource: "plate-depth", withExtension: "txt")!
        return Double(try! String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines))!
    }()

    var body: any Geometry3D {
        let plate = Rectangle(x: width, y: Self.depth).aligned(at: .center)
        // A model's own prints, which the page passes on to the browser's console
        let _ = print("Building a plate \(Int(width)) mm wide")

        // The corner radius is only a parameter when the corners are rounded
        let outline: any Geometry2D
        switch corners {
        case .rounded:
            @Parameter("Corner radius", in: 1...8, step: 0.5, unit: "mm") var radius = 3.0
            outline = plate.rounded(radius: radius)
        case .square:
            outline = plate
        }

        // Holes are 8 mm apart and keep clear of the ends, so how many fit follows the width: four at
        // the default width, and none on the narrowest plates, a range of a single value
        @Parameter("Holes", in: 0...Int((width - 8) / 8), unit: "pcs", description: "Number of holes along the middle")
        var holes = 2

        outline
            .subtracting {
                (0..<holes).mapUnion { index in
                    Circle(radius: 2).translated(x: (Double(index) - Double(holes - 1) / 2) * 8)
                }
            }
            .extruded(height: thick ? 6 : 3)
    }
}
