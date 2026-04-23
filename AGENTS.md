# Idiomatic usage of the Cadova library

## Geometry builders automatically union their children

The `body` property of `Shape2D`/`Shape3D` and the trailing-closure builders of geometry modifier methods (`.subtracting {}`, `.adding {}`, etc.) use `@GeometryBuilder` and automatically union everything they contain. There is no need to wrap children in an explicit `Union {}`.

**Preferred:**
```swift
var body: any Geometry3D {
    Box(10)
    Sphere(radius: 6)
}
```

**Avoid:**
```swift
var body: any Geometry3D {
    Union {
        Box(10)
        Sphere(radius: 6)
    }
}
```

## Use @GeometryBuilder instead of return statements

When a computed property or method needs to compose geometry, annotate it with `@GeometryBuilder2D` or `@GeometryBuilder3D` instead of using a `return` statement.

**Preferred:**
```swift
@GeometryBuilder3D
var trunk: any Geometry3D {
    Cylinder(radius: 5, height: 20)
    Sphere(radius: 5).translated(z: 20)
}
```

**Avoid:**
```swift
var trunk: any Geometry3D {
    return Union {
        Cylinder(radius: 5, height: 20)
        Sphere(radius: 5).translated(z: 20)
    }
}
```

## Prefer .adding {} over explicit Union

When combining a base shape with additional geometry, prefer the `.adding {}` modifier over a standalone `Union {}`.

**Preferred:**
```swift
Box(10)
    .adding {
        Sphere(radius: 6).translated(z: 10)
    }
```

**Avoid:**
```swift
Union {
    Box(10)
    Sphere(radius: 6).translated(z: 10)
}
```

## Don't use Empty() for conditional geometry

Geometry builders support `if` statements directly. An `if` with a false condition outputs nothing — no need to produce an `Empty()` in the else branch.

**Preferred:**
```swift
var body: any Geometry3D {
    Box(10)
    if includeHandle {
        Cylinder(radius: 1, height: 20)
    }
}
```

**Avoid:**
```swift
var body: any Geometry3D {
    Box(10)
    if includeHandle {
        Cylinder(radius: 1, height: 20)
    } else {
        Empty()
    }
}
```

## Prefer working with Angle directly

Use `Angle` as the working type for angular values. Prefer the `°` suffix operator for angle constants. Avoid converting back and forth through raw radians or degrees unless an API strictly requires it. Trigonometric functions operate directly on `Angle`, and `Angle` values can be added, subtracted, multiplied, and otherwise composed directly. Extract `.degrees` or `.radians` only at API boundaries that strictly require scalar values.

**Preferred:**
```swift
let start = 45°
let sweep = 90°
let midpoint = start + sweep / 2
let x = cos(midpoint) * radius
let y = sin(midpoint) * radius
```

**Avoid:**
```swift
let startRadians = Angle.degrees(45).radians
let sweepRadians = Angle(degrees: 90).radians
let midpointRadians = startRadians + sweepRadians / 2
let x = Foundation.cos(midpointRadians) * radius
let y = Foundation.sin(midpointRadians) * radius
```
