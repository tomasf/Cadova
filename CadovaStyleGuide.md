# Cadova style guide

Conventions for writing model code with Cadova. This is not an API reference; it covers the choices
that aren't obvious from the API alone, where several approaches all compile and produce the right
shape but only one reads like Cadova.

If you're an AI agent writing model code, read this first.

## Geometry builders automatically union their children

The `body` property of `Geometry2D`/`Geometry3D` types and the trailing-closure builders of geometry
modifier methods (`.subtracting {}`, `.adding {}`, etc.) use `@GeometryBuilder` and automatically
union everything they contain. There is no need to wrap children in an explicit `Union {}`.

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

When a computed property or method needs to compose geometry, annotate it with `@GeometryBuilder2D`
or `@GeometryBuilder3D` instead of using a `return` statement.

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

When combining a base shape with additional geometry, prefer the `.adding {}` modifier over a
standalone `Union {}`.

**Preferred:**
```swift
Box(10)
    .adding {
        Sphere(radius: 6).translated(z: 10)
        Cylinder(diameter: 2, height: 8)
    }
```

**Avoid:**
```swift
Union {
    Box(10)
    Sphere(radius: 6).translated(z: 10)
    Cylinder(diameter: 2, height: 8)
}
```

## Use Union when there's no primary shape

`.adding {}` groups siblings under a shared modifier perfectly well, so that isn't what separates
the two. The difference is what the code claims: `.adding {}` reads as one shape being the base with
the rest attached to it. When the members are peers, with no natural first among them, `Union {}`
lets them stay peers instead of promoting one into the base position.

```swift
Union {
    hole.translated(x: bottomHoleOffset2)
        .repeated(around: .z, count: 2)

    hole.translated(y: bottomHoleOffset1)
        .repeated(around: .z, count: 2)
}
.rotated(z: 40°)
```

## Constants belong to the type that owns the dimension

Dimensions that other types need are `static let` on the type they describe, and everything derived
from them is computed rather than typed out again. A part's thickness should exist as a number in
exactly one place, so changing it moves everything that depends on it.

**Preferred:**
```swift
struct Rim: Geometry3D {
    static let depth = Wheel.width - Wheel.tireLipThickness
    static let frontThickness = sunBearing.thickness + 1.6
    static let innerDepth = depth - frontThickness
}
```

**Avoid:**
```swift
struct Rim: Geometry3D {
    static let depth = 21.6      // Wheel.width - Wheel.tireLipThickness
    static let frontThickness = 5.6
    static let innerDepth = 16.0 // silently wrong as soon as anything moves
}
```

Use `static var` rather than `static let` when the value reads the environment, since environment
access needs to happen at evaluation time:

```swift
static var bearingSpaceDiameter: Double {
    @Environment(\.tolerance) var tolerance
    return bearing.outerDiameter + tolerance
}
```

## Name local dimensions, don't inline numbers

Dimensions used only within one `body` go in a block of named `let`s at the top, before the geometry
starts. A bare number in the middle of a chain is unreadable and unsearchable.

**Preferred:**
```swift
var body: any Geometry3D {
    let wallThickness = 3.0
    let cableOutletWidth = 8.0
    let cableOutletHeight = 3.0

    Box(x: Servo.boxSize.x + wallThickness * 2, y: Servo.boxSize.y + wallThickness * 2, z: height)
        .subtracting {
            Box(x: cableOutletWidth, y: wallThickness, z: cableOutletHeight)
        }
}
```

**Avoid:**
```swift
var body: any Geometry3D {
    Box(x: Servo.boxSize.x + 6, y: Servo.boxSize.y + 6, z: 15)
        .subtracting {
            Box(x: 8, y: 3, z: 3)
        }
}
```

The exception is a number that is genuinely self-describing in place, like `.rotated(z: 180°)` or a
`* 2` for a symmetric pair.

## Clearances come from the environment

Anywhere a printed part has to fit against hardware or against another printed part, the gap comes
from `\.tolerance`, never from a literal. Read it as a local at the top of `body`, and set the
project's value once in the manifest. This lets the whole model be re-tuned for a different printer
or filament from a single line.

**Preferred:**
```swift
var body: any Geometry3D {
    @Environment(\.tolerance) var tolerance

    Cylinder(diameter: bearing.outerDiameter + tolerance, height: bearing.thickness + tolerance)
}
```

**Avoid:**
```swift
var body: any Geometry3D {
    Cylinder(diameter: bearing.outerDiameter + 0.2, height: bearing.thickness + 0.2)
}
```

Use `.withTolerance(_:)` when one subtree needs a different fit, such as a hole that should be
looser than the rest of the model.

## Build one chain rather than a pile of intermediates

Geometry reads best as a single chain starting from a base shape, with `.adding {}`,
`.subtracting {}` and `.intersecting {}` hanging off it. Introduce a named `let` when a shape is
genuinely reused, not merely to break up a chain.

**Preferred:**
```swift
Cylinder(diameter: outerDiameter, height: bodyHeight)
    .adding {
        Screw(thread: thread, length: threadedHeight)
            .translated(z: outerHeight - threadedHeight)
    }
    .subtracting {
        Cylinder(diameter: innerDiameter, height: outerHeight)
            .translated(z: wallThickness * 2)
    }
```

**Avoid:**
```swift
let base = Cylinder(diameter: outerDiameter, height: bodyHeight)
let screw = Screw(thread: thread, length: threadedHeight).translated(z: outerHeight - threadedHeight)
let withScrew = base.adding { screw }
let bore = Cylinder(diameter: innerDiameter, height: outerHeight).translated(z: wallThickness * 2)
let result = withScrew.subtracting { bore }
```

In a long chain, put a `//` comment above each major addition or subtraction naming the feature it
creates:

```swift
.subtracting {
    // Battery compartment
    ...

    // Power switch
    ...
}
```

## One method call per line

Break a chain so that each call sits on its own line, indented under the receiver. The chain is the
structure of the geometry, and stacking the calls vertically makes that structure scannable: you read
down the left edge and see every operation, in order, without parsing the line horizontally. It also
keeps diffs to the one call that actually changed.

**Preferred:**
```swift
Rectangle(x: width, y: length)
    .aligned(at: .centerX)
    .rounded(insideRadius: 8, outsideRadius: 12)
    .extruded(height: thickness, bottomEdge: .chamfer(depth: 0.4))
```

**Avoid:**
```swift
Rectangle(x: width, y: length).aligned(at: .centerX).rounded(insideRadius: 8, outsideRadius: 12)
    .extruded(height: thickness, bottomEdge: .chamfer(depth: 0.4))
```

Very short examples are the exception. A one-liner carrying a single idea, such as
`Box(size).aligned(at: .centerXY)` or `hole.translated(x: kingpinOffset).symmetry(over: .x)`, reads
perfectly well as it stands. Break the chain as soon as it carries real structure, and always when
the line stops fitting comfortably.

The same applies inside closures. Geometry returned from a builder closure is still a chain:

**Preferred:**
```swift
model.split(along: .z(2)) { over, under in
    over.colored(.darkOrange)
        .translated(z: 7)

    under
}
```

## Model in 2D, then extrude

Cadova's 2D operations are considerably more expressive than its 3D ones. Rounding, offsetting,
insetting and trimming a profile is straightforward in 2D and awkward in 3D, so a refined 2D shape
plus `extruded` or `revolved` usually beats assembling 3D primitives.

**Preferred:**
```swift
Rectangle(x: width, y: length)
    .aligned(at: .centerX)
    .subtracting { wheelCutouts }
    .rounded(insideRadius: 8, outsideRadius: 12)
    .extruded(height: thickness, bottomEdge: .chamfer(depth: 0.4))
```

**Avoid:**
```swift
Box(x: width, y: length, z: thickness)
    .aligned(at: .centerX)
    .subtracting {
        wheelCutouts.extruded(height: thickness)
        // ...and now round the vertical edges the hard way
    }
```

Reach for `.offset(amount:style:)` to derive an inner profile from an outer one, and the two-closure
form when you need both at once:

```swift
outline.offset(amount: -wallThickness, style: .miter) { original, offset in
    original.subtracting { offset }
        .extruded(height: depth)
}
```

## Align instead of translating by half the size

`.aligned(at:)` states where the geometry should sit. Arithmetic on the size to achieve the same
placement has to be re-derived by every reader, and breaks silently when the size changes.

**Preferred:**
```swift
Box(size).aligned(at: .centerXY)
Cylinder(diameter: d, height: h).aligned(at: .maxZ)
```

**Avoid:**
```swift
Box(size).translated(x: -size.x / 2, y: -size.y / 2)
Cylinder(diameter: d, height: h).translated(z: -h)
```

`.whileAligned(at:) { }` applies an operation in an aligned frame and puts the result back, so you
don't have to translate in and out again.

## Repeat and mirror rather than duplicating geometry

Cadova has an operation for every common arrangement. Reaching for one keeps the copies genuinely
identical.

**Preferred:**
```swift
hole.translated(x: kingpinOffset).symmetry(over: .x)
ridge.repeated(around: .z, count: 16)
rib.repeated(along: .x, step: unitWidth, count: 3)
band.distributed(at: [inset, height - inset], along: .z)
```

**Avoid:**
```swift
hole.translated(x: kingpinOffset)
hole.translated(x: -kingpinOffset)
```

Use `.flipped(along:)` with a conditional axis for handed variants of the same part:

```swift
gear.flipped(along: side == .right ? .x : .none)
```

## Two placed shapes plus convexHull is the slot idiom

Elongated holes, lozenges, capsules and tapered arms are all built by placing two simple shapes and
hulling them, not by composing rectangles with rounded ends.

**Preferred:**
```swift
Circle(diameter: width)
    .clonedAt(x: armLength)
    .convexHull()
```

**Avoid:**
```swift
Rectangle(x: armLength, y: width)
    .adding {
        Circle(diameter: width)
        Circle(diameter: width).translated(x: armLength)
    }
```

`.cloned { }` takes a builder, so the same base can be placed several times with different
transforms before hulling.

## Use the built-in operation rather than reconstructing it

Cadova already covers most modelling operations that are tedious to build by hand. Using them keeps
the intent visible and avoids subtly wrong geometry.

- Edge treatments: `.cuttingEdgeProfile(.chamfer(depth:)/.fillet(radius:), on:along:)` and
  `extruded(height:topEdge:bottomEdge:)`, not manually positioned cones and tori.
- Printable horizontal holes: `.overhangSafe()`, not a hand-drawn teardrop profile.
- Threads and fasteners: the [Helical](https://github.com/tomasf/Helical) library (`ScrewThread`,
  `Screw`, `ThreadedHole`, `Bolt`, `Nut`), not hand-modelled helices.
- Stacking parts end to end: `Stack(.z) { }`, not a running Z offset you maintain yourself.
- Placing a feature relative to something defined inside another type: `Anchor` with
  `.definingAnchor()` and `.anchored(to:)`, not a recomputed transform at the call site.
- Splitting a model into printable pieces: `.split(along:)` or `.separating(into:)`, not a
  hand-built cutting box subtracted twice.

## Model variants belong in a configuration type

When one design is generated at several sizes or in several flavours, collect the measurements into
a `Configuration` struct with derived values as computed properties, and pass it through a custom
environment key. Scattered booleans and `if size == .large` branches inside geometry don't scale.

```swift
struct Configuration {
    let name: String
    let candlesPerLeg: Int
    let legAngle: Angle
    let wallThickness: Double
    // ...
}

extension Configuration {
    var legLength: Double { outerTriangleHalf.hypotenuse }
    var bottomAngle: Angle { 90° - legAngle / 2 }
}

extension EnvironmentValues {
    private static let key = Key("MyProject.Configuration")

    var configuration: Configuration {
        get { self[Self.key] as! Configuration }
        set { self[Self.key] = newValue }
    }
}
```

Geometry then reads it the same way it reads tolerance:

```swift
var body: any Geometry3D {
    @Environment(\.configuration) var config
    ...
}
```

## Don't use Empty() for conditional geometry

Geometry builders support `if` statements directly. An `if` with a false condition outputs nothing,
so there's no need to produce an `Empty()` in the else branch.

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

Use `Angle` as the working type for angular values. Prefer the `°` suffix operator for angle
constants. Avoid converting back and forth through raw radians or degrees unless an API strictly
requires it. Trigonometric functions operate directly on `Angle`, and `Angle` values can be added,
subtracted, multiplied, and otherwise composed directly. Extract `.degrees` or `.radians` only at API
boundaries that strictly require scalar values.

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

## Naming

All dimensions are in millimeters, so names carry no units. Prefer diameters over radii, since
Cadova's API is diameter-first and mixing the two is a reliable source of factor-of-two bugs. Use
consistent suffixes so related values sort and read together: `…Diameter`, `…Thickness`, `…Width`,
`…Height`, `…Depth`, `…Length`, `…Offset`, `…Inset`, `…Margin`, `…Count`.

```swift
let ridgeWidth = 10.0
let ridgeDepth = 0.5
let ridgeInset = 20.0
let ridgeCount = 16
```

## Keep main.swift a manifest

The top-level file lists what gets built and nothing else: project metadata, environment defaults,
and one `Model` per output file. Geometry belongs in its own type, in its own file. Use `Group` to
nest related outputs such as print plates.

```swift
await Project(packageRelative: "Models") {
    Metadata(title: "Trash Can Dice Game", author: "...", license: "MIT")

    Environment {
        $0.tolerance = 0.15
        $0.circularOverhangMethod = .bridge
    }

    await Model("Dice") {
        Dice(style: .player1)
    }

    await Group("Platters") {
        await Model("Dice Platter") { Platter() }
    }
}
```
