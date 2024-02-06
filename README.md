# SwiftSCAD
SwiftSCAD is a library that allows you to create 3D and 2D CAD models in Swift. It acts as a preprocessor for [OpenSCAD][openscad], generating .scad files that can be previewed and rendered using the OpenSCAD application. This offers a more convenient API, breaking away from the limitations of the OpenSCAD language.

SwiftSCAD runs on macOS, Windows and Linux.

[![Swift](https://github.com/tomasf/SwiftSCAD/actions/workflows/swift.yml/badge.svg)](https://github.com/tomasf/SwiftSCAD/actions/workflows/swift.yml)

# Usage
Create a new Swift executable package:

```
$ mkdir My3DGadget
$ cd My3DGadget
$ swift package init --type executable
```

Add SwiftSCAD as a dependency for your package in Package.swift:

<pre>
let package = Package(
    name: "My3DGadget",
    dependencies: [
        <b><i>.package(url: "https://github.com/tomasf/SwiftSCAD.git", branch: "main"),</i></b>
    ],
    targets: [
        .executableTarget(name: "My3DGadget", dependencies: [<b><i>"SwiftSCAD"</i></b>])
    ]
)
</pre>

In your code, import SwiftSCAD, create geometry and save it:

```swift
import SwiftSCAD

Box([10, 10, 5])
    .subtracting {
        Sphere(diameter: 10)
            .translated(z: 5)
    }
    .save(to: "gadget.scad")
```

Run your code using `swift run` to generate the .scad file. Open it in OpenSCAD to preview your model. For the best experience, hide the editor view using *View > Hide Editor* and enable *Design > Automatic Reload and Preview*. With this in place, OpenSCAD will reload automatically every time you run your code after making changes to the model.

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
        Circle(diameter: centerSize)
        .adding {
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