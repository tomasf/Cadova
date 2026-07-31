# Anchors and Tags

Capture a position or a piece of geometry at one point in your model and reference it again elsewhere.

## Overview

Most of the time, geometry only relates to its immediate neighbors: you build a shape, then subtract or add something right next to it. But some relationships span the whole model; a mounting boss needs to line up with a hole defined in a completely different part of your code, or a cross-section cut in one place needs to be reused somewhere else. Cadova has two mechanisms for this, both working the same way: define something once, anywhere in the tree, then reference it later, anywhere else.

- ``Anchor`` captures a coordinate frame (a position and orientation) so you can place *new* geometry there.
- ``Tag`` captures a piece of geometry itself, so you can reuse the *same* geometry again elsewhere.

Both share the same resolution model: definitions and references can appear in any order in your code — a reference can even come before its definition — because Cadova resolves them after the surrounding geometry has been built. If a reference has no matching definition by the time the model is complete, it produces no geometry and a warning is printed.

## Anchors

### Defining an anchor

Create an ``Anchor``, optionally with a label for debugging, and attach it to geometry with `.definingAnchor(_:at:offset:pointing:rotated:)`. This captures the geometry's current coordinate frame, optionally adjusted by an alignment, offset, direction, and rotation, as the anchor's recorded transform:

```swift
let screwHole = Anchor("screw hole")

Box(x: 40, y: 20, z: 5)
    .definingAnchor(screwHole, at: .top, .centerXY)
```

`at:` takes the same alignment presets used by `.aligned(at:)` (see <doc:AlignmentAndStacking>) to pick a point on the geometry's bounding box; with no alignment, the anchor sits at the origin. In 3D, `pointing:` chooses which direction becomes the anchor's local up, and `rotated:` spins it around that direction, useful for orienting a part that will be placed there, such as a screw pointing into the hole.

### Placing geometry at an anchor

`.anchored(to:)` places geometry at every transform recorded for an anchor:

```swift
Cylinder(diameter: 3, height: 10)
    .anchored(to: screwHole)
```

If the anchor was defined more than once, the geometry is duplicated, once per definition. A single `.anchored(to:)` call can place a screw at every hole in a pattern. Because resolution happens after the whole tree is built, it doesn't matter whether the anchor is defined before or after the geometry that references it.

## Tags

### Tagging geometry

A ``Tag`` marks a specific piece of geometry — not just a position — so it can be reused elsewhere. Create one and apply it with `.tagged(_:)`:

```swift
let coreCut = Tag("core cut")

Box(20)
    .aligned(at: .centerXY)
    .subtracting {
        Cylinder(diameter: 8, height: 20)
            .tagged(coreCut)
    }
```

The tag records the geometry's world-space position at the moment `.tagged(_:)` is called, including any transforms already applied to it.

### Referencing tagged geometry

A `Tag` is itself a piece of geometry: using it anywhere reproduces everything tagged with it, at the exact world position it had when tagged:

```swift
Cylinder(diameter: 1, height: 30)
    .intersecting {
        coreCut
    }
```

This world-anchoring is the central property of tags: transforms applied to an *ancestor* of the reference are cancelled out, so the reference always reproduces its content at the original captured position, no matter where in the tree it's used. Transforms chained *directly* onto the reference, on the other hand, do move it, applied in the local coordinate frame at the call site, the same way transforms compose on any other geometry:

```swift
coreCut.translated(x: 10)   // moves the reference
coreCut
    .adding {...}
    .translated(x: 10)      // does not
```

If a tag was applied more than once, a reference merges (unions) every tagged instance into one result. This makes tags useful not just for reuse, but for aggregating geometry scattered across a model under one identifier.

## Related Reading

- <doc:AlignmentAndStacking> for the alignment presets used by `.definingAnchor(at:...)`.
- <doc:EnvironmentConcepts> for how the environment carries definitions through the tree so they can be found regardless of where a reference appears.
