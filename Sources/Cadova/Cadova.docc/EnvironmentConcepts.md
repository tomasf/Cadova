# Environment

Use environment values to control modeling behavior across geometry trees.

## Overview

Cadova's ``EnvironmentValues`` system provides a clean, declarative way to control modeling behavior across entire geometry trees, much like SwiftUI. This allows settings like resolution, tolerance, and material to apply consistently and implicitly, reducing the need for repetitive parameters in your modeling code. Environment values wrap around geometry and propagate through the tree unless explicitly overridden.

Cadova has several built-in environment settings. For example, segmentation controls the number of straight segments used for curved surfaces like circles and curves. Other settings include the fill rule for polygons, the miter limit for offsets, and the maximum twist rate for sweeps, among others.

## What Is the Environment For?

The environment injects shared configuration into a subtree of your geometry. It flows down the tree, or rather *wraps around* the geometry it's attached to. Any geometry inside will receive those values, unless they're overridden further in.

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

In this example, the segmentation settings apply to the sphere and the cylinder, but not the circle, because the `.withSegmentation(...)` is only applied to the subtree above it.

This system makes it easy to apply shared settings without passing explicit parameters to every single node.

## Reading Environment Values

Use the `@Environment` property wrapper, much like SwiftUI's `@Environment`, to read values directly wherever you need them: in the body of a custom ``Geometry2D`` or ``Geometry3D`` type, or inline inside any geometry builder, such as `.adding` or `.subtracting`.

In a custom shape, this is ideal for defining reusable parametric shapes that adapt to configuration:

```swift
struct MyShape: Geometry3D {
    var body: any Geometry3D {
        @Environment(\.tolerance) var tolerance
        Box(x: 10.0 + tolerance, y: 12.0 + tolerance, z: 4)
    }
}

await Model("shape") {
    MyShape()
        .withTolerance(0.3)
}
```

The same property wrapper works directly inside a builder, without defining a new type:

```swift
Box(10)
    .aligned(at: .centerXY)
    .subtracting {
        @Environment(\.tolerance) var tolerance
        Cylinder(diameter: 5.0 + tolerance, height: 10)
    }
```

There's also a `.readingEnvironment(...)` modifier, which reads a value and passes it into a closure that adjusts an existing geometry.

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

A custom value isn't limited to a simple scalar like the `Double` above — it can just as well be a struct bundling several related settings, letting you thread a whole shared configuration through a subtree as a single environment value instead of one entry per field.
