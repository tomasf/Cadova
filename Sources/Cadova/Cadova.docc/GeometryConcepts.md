# Geometry

Understand how Cadova models geometry, how you build and combine shapes, and how to think about units and dimensions.

## Overview

To use Cadova effectively, it helps to understand how it models geometry, how you build and combine shapes, and how to think about units and dimensions. If you're familiar with SwiftUI, you'll find that Cadova shares a similar declarative and compositional style.

## Geometry: The Building Block

At the heart of Cadova is the ``Geometry`` protocol. This protocol is generic over a type called ``Dimensionality``, which distinguishes between 2D and 3D geometries. Most of the time, though, you'll interact with the type aliases:

- ``Geometry2D``, for two-dimensional geometry
- ``Geometry3D``, for three-dimensional geometry

When you create your own geometry types, you typically conform to either ``Shape2D`` or ``Shape3D``, which conform to ``Geometry``, and implement the `body` property:

```swift
struct MyThing: Shape3D {
    var body: any Geometry3D {
        // Your shape composition here
    }
}
```

Just like `View` in SwiftUI, a ``Geometry`` is a lightweight value type that acts as a description of how geometry should be built. Instances can be composed, transformed, passed around, and reused.

## Composition and Transformation

Cadova models are typically constructed by combining and transforming simpler shapes. You'll use methods like:

- `.adding { ... }`
- `.subtracting { ... }`
- `.intersecting { ... }`

...or their freestanding equivalents:

```swift
Union {
    shapeA
    shapeB
}

Intersection {
    shapeA
    shapeB
}
```

You can apply transformations to geometry:

- `.translated(x:y:)`, `.translated(x:y:z:)`
- `.rotated(x:y:z:)` (Euler angles)
- `.scaled(...)`
- `.transformed(...)`

Cadova includes a standard library of primitive shapes: ``Circle``, ``Rectangle``, ``Sphere``, ``Box``, ``Cylinder``, and more.

To export your model, wrap it in a ``Model``:

```swift
Model("myModel") {
    Cylinder(diameter: 5, height: 10)
        .adding { ... }
}
```

## Reuse and Abstraction

The recommended way to build reusable components is by defining new types that conform to ``Shape2D`` or ``Shape3D``. This makes your geometry composable and clean:

```swift
struct Bracket: Shape3D {
    let size: Double

    var body: any Geometry3D {
        Box(x: size, y: size / 2, z: size / 4)
    }
}
```

However, this isn't always necessary. Because geometries are just values, it's often fine to use functions that return geometry, especially for small or parameterized components. The system is flexible — use whatever feels practical.

## 2D vs 3D Modeling

Cadova supports both 2D and 3D workflows. You can either start in 2D (e.g. ``Rectangle``, ``Polygon``) and extrude to 3D or model directly in 3D using primitives like ``Sphere``, ``Box``, and ``Cylinder``.

Cadova models always represent physical geometry with volume (in 3D) or area (in 2D). There are no zero-thickness surfaces, edges, or points in the final output. Even if you define something like a plane or a curve, once it becomes part of a shape, it gains measurable size.

Many operations are available for both 2D and 3D geometries, but some are specific to one or the other. Since ``Geometry2D`` and ``Geometry3D`` are distinct types, they cannot be used interchangeably. To convert 2D shapes into 3D, use an extrusion method like `.extruded(height:)`, `.revolved(in:)`, or `.swept(along:)`. Converting 3D into 2D is less common, but possible with operations like `.projected()` or `.sliced(...)`.
