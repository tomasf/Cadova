# Vectors and Angles

Work with positions, sizes, and rotations using Cadova's vector and angle types.

## Overview

Cadova uses ``Vector2D`` and ``Vector3D`` to represent positions, sizes, and displacements in 2D and 3D space. They appear throughout the API, for example, when specifying the size of a ``Box`` or ``Rectangle``, or when applying transformations. Vector and angle types are used extensively to represent geometry in 2D and 3D space. These types are lightweight, expressive, and designed to make geometric modeling feel natural in Swift.

Cadova uses *millimeters* as the default unit for distances and coordinates. All measurements are expressed as `Double` values, but the vector types themselves are unitless — they can be used to represent any kind of numerical value. For example, a ``Vector3D`` might represent a size in millimeters, a displacement in space, or even a scaling factor.

## Vector Types

Cadova provides two main vector types:

- ``Vector2D`` — for 2D space
- ``Vector3D`` — for 3D space

Both types work similarly and support:

- Arithmetic operations (`+`, `-`, `*`, `/`)
- Dot products (`⋅`) and cross products (`×`, only for ``Vector3D``)
- Scalar multiplication and division
- Array literal initialization

### Creating Vectors

You can initialize a vector in several ways:

```swift
let v1 = Vector2D(x: 10, y: 20)
let v2: Vector2D = [10, 20]

let v3 = Vector3D(x: 5, y: 15, z: -3)
let v4: Vector3D = [5, 15, -3]
```

You can also construct vectors using `.x(...)`, `.y(...)`, and `.z(...)` factory methods for convenience. These set the specified axis and leave all others as zero:

```swift
let vertical: Vector2D = .y(100)
let forward: Vector3D = .z(30)
```

### Arithmetic

Vectors support component-wise arithmetic:

```swift
let a: Vector2D = [10, 20]
let b: Vector2D = [5, 4]
let sum = a + b       // [15, 24]
```

You can also mix vector and scalar values:

```swift
let offset = a - 5    // [5, 15]
let doubled = 2 * b   // [10, 8]
```

### Dot and Cross Products

Cadova provides two common geometric operations on vectors. The *dot product* (`⋅`) returns a scalar value and measures alignment between vectors. The *cross product* (`×`) returns a vector perpendicular to two inputs, and is only available for ``Vector3D``.

```swift
let a: Vector2D = [1, 0]
let b: Vector2D = [0, 1]
let dot = a ⋅ b       // 0

let xAxis: Vector3D = [1, 0, 0]
let yAxis: Vector3D = [0, 1, 0]
let zAxis = xAxis × yAxis   // [0, 0, 1]
```

## Angle

Angles in Cadova are represented by the ``Angle`` type. Angles are *unitless*. You create them using degrees, radians, or full turns, but once created, an ``Angle`` simply represents a rotation, not a particular unit. The most natural and preferred way to create angles is by using the `°` suffix operator:

```swift
let rightAngle = 90°
```

You can also create angles using degrees, radians, or full turns:

```swift
let a1 = Angle(degrees: 90)
let a2 = Angle(radians: .pi / 2)
let a3 = Angle(turns: 0.25)
```

Angles support arithmetic and comparisons:

```swift
let total = 90° + 45°
let diff = a1 - a2
if diff < 5° {
    print("Close enough")
}
```

Angles also have computed properties for conversion:

```swift
let a = 180°
print(a.radians)   // 3.141592...
print(a.turns)     // 0.5
```

Normalization is available via `.normalized`, which maps any angle to the range -180°...180°.
