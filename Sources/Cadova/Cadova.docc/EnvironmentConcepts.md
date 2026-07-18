# Environment

Use environment values to control modeling behavior across geometry trees.

## Overview

Cadova's ``EnvironmentValues`` system provides a clean, declarative way to control modeling behavior across entire geometry trees, much like SwiftUI. This allows settings like resolution, tolerance, and material to apply consistently and implicitly, reducing the need for repetitive parameters in your modeling code. Environment values wrap around geometry and propagate through the tree unless explicitly overridden.

Cadova has several built-in environment settings. For example, segmentation controls the number of straight segments used for curved surfaces like circles and curves. Other settings include the fill rule for polygons, the miter limit for offsets, and the maximum twist rate for sweeps, among others.

## What Is the Environment For?

The environment injects shared configuration into a subtree of your geometry. It flows down the tree — or rather *wraps around* the geometry it's attached to. Any geometry inside will receive those values, unless they're overridden further in.

```swift
Sphere(radius: 3)
    .adding {
        Cylinder(diameter: 2, height: 1)
    }
    .withSegmentation(minAngle: 1°, minSize: 0.5)
    .adding {
        Circle(radius: 2).revolved()
    }
```

In this example, the segmentation settings apply to the sphere and the cylinder, but not the circle — because the `.withSegmentation(...)` is only applied to the subtree above it.

This system makes it easy to apply shared settings without passing explicit parameters to every single node.

## Reading Environment Values

There are two primary ways to read values from the environment:

### Using `.readingEnvironment(...)`

This modifier reads a value from the environment and passes it into a closure:

```swift
Box(2)
    .readingEnvironment(\.tolerance) { box, tolerance in
        box.resized(x: 1 + tolerance)
    }
    // ...
    .withTolerance(0.5)
```

Use this when you want to adjust an existing geometry based on the environment context.

### Using the `@Environment` Property Wrapper

If you're defining your own ``Shape2D`` or ``Shape3D``, you can use the `@Environment` property wrapper to access values directly:

```swift
struct MyShape: Shape3D {
    @Environment(\.tolerance) var tolerance

    var body: any Geometry3D {
        Box(x: 10.0 + tolerance, y: 12.0 + tolerance, z: 4)
    }
}

await Model("shape") {
    MyShape()
        .withTolerance(0.3)
}
```

This works much like SwiftUI's `@Environment` and is ideal for defining reusable parametric shapes that adapt to configuration. You can also use it inside geometry builders:

```swift
Box(10)
    .aligned(at: .centerXY)
    .subtracting {
        @Environment(\.tolerance) var tolerance
        Cylinder(diameter: 5.0 + tolerance, height: 10)
    }
```

## Custom Values

You can define your own environment values. This is useful for advanced users and custom geometry behavior.

```swift
extension EnvironmentValues {
    private static let key = Key("MyName.MyCustomValue")

    var myCustomValue: Double? {
        get { self[Self.key] as? Double }
        set { self[Self.key] = newValue }
    }
}

extension Geometry {
    func withMyCustomValue(_ value: Double) -> D.Geometry {
        withEnvironment { $0.myCustomValue = value }
    }
}
```
