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

A value that describes a length is measured in the coordinate system where you set it. That covers segmentation's `minSize` and `tolerance`: writing `.withSegmentation(minAngle: 1°, minSize: 0.5)` inside a `.scaled(...)` means half a unit of the geometry it's attached to, not half a unit of the finished model. See <doc:Transformations> for how the environment tracks that.

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

## Customizer Parameters

Parameters make a model configurable from the outside without editing its source code. Declare them with the ``Parameter`` property wrapper, giving each one a name and a default value:

```swift
struct GridPlate: Geometry3D {
    @Parameter("columns") var columns = 4
    @Parameter("height") var height = 20.0

    var body: any Geometry3D {
        // ...
    }
}
```

When building the model, override values from the command line:

```
$ my-model --param columns=8 --param height=25.5
```

Parameter values flow through the environment, so everything that applies to environment values applies to parameters too. Command-line values apply at the root of the model, and more local settings win — a parameter set in code, whether through an `Environment` directive or ``Geometry/withParameter(_:_:)``, takes precedence over a command-line value:

```swift
GridPlate()
GridPlate().withParameter("columns", 8)
    .translated(y: 60)
```

Supported parameter types include `Int`, `Double`, `Bool`, `String`, `Angle`, and string-backed enums that declare conformance to ``ParameterValue``. Because parameters are resolved from the active environment, read them inside a model context — within a `Model { }` builder, a geometry's `body`, or another geometry callback. Outside of a model, a parameter returns its default value.

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

## Related Reading

- [Tutorial 6: Your own shapes](https://cadova.org/tutorials/#06), a short video that fits a lid to its box with the tolerance from the environment
