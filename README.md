# SwiftSCAD
SwiftSCAD is a library that allows you to create 3D and 2D CAD models in Swift. It acts as a preprocessor for [OpenSCAD][openscad], generating .scad files that can be previewed and rendered using the OpenSCAD application. This offers a more convenient API, breaking away from the limitations of the OpenSCAD language.

# Usage
SwiftSCAD is distributed as a Swift Package. The following steps will guide you through using it in a new Swift project.

1. **Download and install the [OpenSCAD][openscad] application**. This will be used as the viewer and renderer.
2. **Create a new Swift project** using either the `swift package` CLI or Xcode. It's up to you to decide if you want to have a single project for all of your different CAD models, or one project per model. Having a single project might mean less overhead if you tend to make lots of small models, but might get unwieldy if you tend to build larger, more complex models.

    Using an Xcode project instead of a Swift package offers the benefit of customizing the working directory for running the scheme. By setting the custom working directory to `$(PROJECT_DIR)`, you can make the `save(to:)` method output files relative to the project directory.

3. **Add `https://github.com/tomasf/SwiftSCAD` as a dependency** by adding it to your `Package.swift` file or by using Xcode's GUI.
4. **`import SwiftSCAD`** in the file(s) where you want to use SwiftSCAD. Adding it to `main.swift` can be a good place to start.
5. **Use the SwiftSCAD API** to create a model. Refer to the _Examples_ section for more details.
6. **Generate a .scad file** for the model by adding the `Geometry2D/save(to:)` or `Geometry3D/save(to:)` method to the end of the model declaration and then Building and Running the project. Make sure any intermediate directories already exist.
7. **Open the .scad file in OpenSCAD** to preview your model. For the best experience, make sure you hide the editor view by going to `View > Hide Editor` and enable automatic reload by going to `Design > Automatic Reload and Preview`. With this in place, OpenSCAD will reload automatically every time you Build and Run your project after making changes to the model.
8. **Render and export the model** from OpenSCAD using `Design > Render` followed by `File > Export`.

# Examples

## Rotated box
![Example 1](https://tomasf.se/projects/swiftscad/examples/example1.png)

```swift
Box([10, 20, 5], center: .y)
    .rotated(y: -20°, z: 45°)
    .save(to: "~/Desktop/examples/example1.scad")
```

## Extruded star with subtraction
![Example 2](https://tomasf.se/projects/swiftscad/examples/example2.png)

```swift
Circle(diameter: 10)
    .withFacets(count: 3)
    .translated(x: 2)
    .scaled(x: 2)
    .repeated(in: 0°..<360°, count: 5)
    .rounded(amount: 1)
    .extruded(height: 5, twist: 20°, slices: 20)
    .subtracting {
        Cylinder(bottomDiameter: 1, topDiameter: 5, height: 20)
            .translated(y: 2, z: -7)
            .rotated(x: 20°)
            .highlighted()
    }
    .save(to: "example2.scad")
```

## Reusable star shape
![Example 3](https://tomasf.se/projects/swiftscad/examples/example3.png)

```swift
struct Star: Shape2D {
    let pointCount: Int
    let radius: Double
    let pointRadius: Double
    let centerSize: Double

    var body: Geometry2D {
        Union {
            Circle(diameter: centerSize)
            Circle(radius: max(pointRadius, 0.001))
                .translated(x: radius)
        }
        .convexHull()
        .repeated(in: 0°..<360°, count: pointCount)
    }
}

Union {
    Star(pointCount: 5, radius: 10, pointRadius: 1, centerSize: 4)
    Star(pointCount: 6, radius: 8, pointRadius: 0, centerSize: 2)
        .translated(x: 20)
}
.save(to: "example3.scad")
```

## Extruding along a Bezier path
![Example 4](https://tomasf.se/projects/swiftscad/examples/example4.png)

```swift
let path = BezierPath(startPoint: .zero)
    .addingCubicCurve(controlPoint1: [10, 65], controlPoint2: [55, -20], end: [60, 40])

Star(pointCount: 5, radius: 10, pointRadius: 1, centerSize: 4)
    .usingDefaultFacets()
    .extruded(along: path, radius: 11)
    .usingFacets(minAngle: 5°, minSize: 1)
    .save(to: "example4.scad")
```

[openscad]: https://openscad.org