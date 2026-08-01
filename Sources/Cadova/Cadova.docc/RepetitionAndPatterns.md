# Repetition and Patterns

Stamp out many copies of a shape in rows, grids, rings, along a path, or mirrored, instead of placing each one by hand.

## Overview

A great deal of mechanical design is repetition: a row of mounting holes, a circle of bolts, a grid of cooling fins, teeth around a gear. Rather than writing the same shape many times at hand-computed positions, you describe it once and let Cadova replicate it.

Every method on this page follows the same shape. You start with one geometry and get back a new geometry that contains all the copies, already combined into a single result. That means you can keep working with the whole pattern as one piece: transform it, subtract it from something else, or feed it into another repetition. The methods compose freely, and most work in both 2D and 3D.

## Rows and grids

`.repeated(along:count:)` lays copies out along an axis. The most direct form takes a `spacing` and a `count`:

```swift
Cylinder(diameter: 5, height: 6)
    .repeated(along: .x, spacing: 8, count: 5)
    .repeated(along: .y, spacing: 8, count: 4)
```

![A five by four grid of identical cylindrical pegs](patterns-grid)

The two calls chain to build a grid: the first makes a row of five along X, and the second repeats that whole row four times along Y. Because each call returns a normal geometry, stacking them is all it takes to go from a row to a grid to a 3D lattice.

A few variants let you specify the spacing in whichever way is most natural:

- `spacing:` is the gap left *between* the bounding boxes of neighboring copies, so it adapts to the size of the shape.
- `step:` is the fixed center-to-center distance instead.
- `in:count:` and `in:step:` spread copies across an explicit coordinate range.
- `in:minimumSpacing:` fills a range with as many copies as fit, then evens out the spacing for you.

## Radial patterns

`.repeated(around:count:)` rotates copies evenly around an axis, which is the tool for anything arranged in a circle:

```swift
Union {
    Cylinder(diameter: 16, height: 10)
    Cylinder(diameter: 5, height: 10)
        .translated(x: 18)
        .repeated(around: .z, count: 8)
}
```

![A central hub surrounded by a ring of eight evenly spaced posts](patterns-radial)

A single post is moved out to a radius of 18 mm, then repeated eight times around the Z axis to form a bolt circle around the hub. By default the copies fill a full turn. Pass a range to sweep only part of a circle, for example `.repeated(around: .z, in: 0°..<180°, count: 5)` for a fan, and use `step:` instead of `count:` to fix the angle between copies. In 2D the same method drops the axis: `.repeated(count:)`.

## Following a path

Repetition isn't limited to straight lines and circles. `.repeated(along:count:)` distributes copies along any ``ParametricCurve``, such as a ``BezierPath3D``:

```swift
let arch = BezierPath3D {
    curve(controlX: 15, controlY: 0, controlZ: 55, endX: 60, endY: 0, endZ: 55)
    curve(controlX: 105, controlY: 0, controlZ: 55, endX: 120, endY: 0, endZ: 0)
}

Box([5, 16, 7])
    .aligned(at: .center)
    .repeated(along: arch, count: 18)
```

![Eighteen identical blocks distributed at even intervals along an arched path](patterns-along-path)

By default the copies are simply moved to evenly spaced points along the path, each keeping its original orientation, which is what you see above. To make the copies turn as they travel, pass a `target`. Cadova then aims the geometry's local positive Z axis forward along the path, and rotates it around that axis so a chosen local direction, `reference` (a direction in the geometry's own XY plane, `.down` by default), points toward the `target`. This is the same target-and-reference scheme used to orient swept geometry, described in <doc:CurvesAndPaths>. Use `spacing:` in place of `count:` to place copies a fixed distance apart along the curve.

## Mirroring

`.symmetry(over:)` reflects geometry across one or more axes, adding the mirror images to the original. It's the natural way to build something symmetrical from a single representative piece:

```swift
Union {
    Box([24, 6, 10]).aligned(at: .minXY, .bottom)
    Box([6, 24, 10]).aligned(at: .minXY, .bottom)
}
.translated(x: 3, y: 3)
.symmetry(over: [.x, .y])
```

![One L-shaped piece mirrored across both the X and Y axes to form a symmetric four-armed shape](patterns-symmetry)

Here a single L in one quadrant is mirrored over both the X and Y axes, producing four copies in total that together form a symmetric figure. Design one quadrant, mirror it, and the whole stays consistent when you change that one piece.

## Single copies and arbitrary arrangements

When you don't want a regular pattern, two tools cover the rest.

`.cloned(_:)` adds a single transformed copy alongside the original, which is handy for a mirrored or rotated duplicate without repeating yourself:

```swift
shape.cloned { $0.rotated(z: 45°) }   // the original plus one rotated copy
```

The `.clonedAt(x:y:z:)` and `.cloned(at:)` shortcuts do the same for a simple translation.

`.distributed(at:)` places copies at a set of positions or transforms you supply directly, for arrangements that don't follow a rule:

```swift
Cylinder(diameter: 3, height: 10)
    .distributed(at: [0, 8, 20, 36], along: .x)
```

Besides a list of offsets along an axis, `distributed(at:)` also accepts vectors, full transforms, or a list of angles, giving you complete control over where each copy lands.
