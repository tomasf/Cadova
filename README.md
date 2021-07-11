# SwiftSCAD
SwiftSCAD is a library that allows you to create 3D/2D CAD models in Swift. SwiftSCAD is a preprocessor for OpenSCAD – it generates .scad files that you can preview and render using the OpenSCAD application. This frees you from the limitations of the OpenSCAD language and provides a more convenient API.

# Usage
Add the SPM package https://github.com/tomasf/SwiftSCAD

In OpenSCAD, make sure to hide the editor view and enable "Automatic Reload and Preview".

# Examples

## Rotated box
![Example 1](http://tomasf.se/projects/swiftscad/examples/example1.png)

```swift
Box([10, 20, 5], center: .y)
    .rotated(y: -20°, z: 45°)
    .save(to: "~/Desktop/test.scad")
```

## Extruded star with subtraction
![Example 2](http://tomasf.se/projects/swiftscad/examples/example2.png)

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
    .save(to: "~/Desktop/test.scad")
```

## Reusable star shape
![Example 3](http://tomasf.se/projects/swiftscad/examples/example3.png)

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
.save(to: "~/Desktop/test.scad")
```
