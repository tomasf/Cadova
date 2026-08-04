# Designing for 3D Printing

Practical techniques for making models that print cleanly: overhang-safe holes, self-supporting edges, print-fit tolerances, and per-part print settings.

## Overview

Cadova's core geometry API is print-agnostic — a `Box` is just a box. But since Cadova is built with 3D printing as its focus, it includes a handful of features specifically aimed at producing models that print reliably on FDM printers, ideally without manual support removal or fiddly fit adjustments.

## Overhangs on circles and cylinders

Circular holes and pillars are a common source of unsupported overhangs: printed horizontally, the top of a circular hole has to bridge across empty space with no material underneath it. `.overhangSafe(_:)` reshapes a `Circle` or `Cylinder` to eliminate this:

```swift
Cylinder(diameter: 10, height: 20)
    .overhangSafe(.teardrop)
    .rotated(y: 90°)
```

![A horizontal cylinder with a teardrop-shaped end instead of a circular one](designing-for-3d-printing-overhang-safe)

The rotation matters here: relief is added within the circle's own plane, so it only has an effect when that plane contains the up direction — as it does once the cylinder is lying on its side. A cylinder left standing upright, with its circular faces already horizontal, has nothing to fix and `.overhangSafe(_:)` leaves it unchanged.

Two relief methods are available:

- `.teardrop` extends the top of the shape to a point, so no stretch of new material has to bridge unsupported.
- `.bridge` flattens the top into a straight, bridgeable span instead, keeping more of the original circular profile.

`.overhangSafe(_:)` figures out which way is "up" and whether to extend the top or the bottom on its own:

- Direction comes from the environment's `naturalUpDirection`, which defaults to world +Z. If a shape has been rotated before this is applied, set the up direction explicitly with `.definingNaturalUpDirection(_:)` so the relief still points the right way for the printer.
- Whether the *top* or the *bottom* is extended depends on whether the shape is being added or subtracted — subtracted shapes (holes) extend upward, added shapes (pillars, bosses) extend downward.

Both the overhang angle threshold and the default relief method can be set for a whole subtree via the environment, instead of at each call site:

```swift
Box(x: 20, y: 20, z: 10)
    .aligned(at: .center)
    .subtracting {
        Cylinder(diameter: 8, height: 20)
            .overhangSafe()
            .aligned(at: .centerZ)
            .rotated(y: 90°)
    }
    .withOverhangAngle(50°)
    .withCircularOverhangMethod(.bridge)
```

![A centered box with a horizontal, overhang-safe hole through its middle](designing-for-3d-printing-overhang-hole)

Here the box is centered on the origin, and the hole is drilled horizontally through its middle rather than straight up, the situation `.overhangSafe()` actually exists for, since the top of a horizontal hole is exactly the kind of unsupported overhang FDM printers struggle with. `.overhangSafe()` must be called directly on the `Cylinder` before any alignment or rotation, since it's specific to that type, but the relief it adds still comes out correctly oriented after the subsequent `.rotated(y: 90°)`, because the direction it extends in is resolved from the environment's `naturalUpDirection` at build time, which accounts for every transform applied above it in the tree, regardless of chain order.

`overhangAngle` defaults to 45°, a safe value for most FDM printers.

## Self-supporting edges

Sharp overhanging edges can use the same idea. For an additive shape sitting on the print bed, a fillet on a *bottom* edge is the one that's printability-sensitive: as printing moves upward from the inset bottom face, each layer has to extend outward past the one below it, which is an overhang. A fillet on a *top* edge has the opposite, always-safe shape — it recedes inward as it approaches the top, so it's already fully supported by the layer beneath it. `EdgeProfile.overhangFillet(radius:)` is a fillet that respects the current `overhangAngle`, curving into a teardrop shape where a plain radius on a bottom edge would exceed the printable overhang and require support:

```swift
Box(x: 20, y: 20, z: 10)
    .cuttingEdgeProfile(.overhangFillet(radius: 3), on: .bottom)
```

![A box with a self-supporting, teardrop-shaped fillet along its bottom edge](designing-for-3d-printing-overhang-fillet)

This is a drop-in replacement for `.fillet(radius:)` anywhere the resulting edge will be printed as an unsupported overhang, such as the bottom rim of a box sitting directly on the print bed.

## Fit and tolerance

`tolerance` is a plain `Double` in the environment. Cadova doesn't apply it to geometry automatically, but it's a conventional place to store a print-fit clearance so it can be read consistently across a model instead of being hardcoded in multiple places:

```swift
Box(x: 20, y: 20, z: 4)
    .aligned(at: .centerXY)
    .subtracting {
        @Environment(\.tolerance) var tolerance
        Cylinder(diameter: 5 + tolerance, height: 4)
    }
    .withTolerance(0.2)
```

See <doc:EnvironmentConcepts> for more on reading and setting environment values like this one.

## Segmentation and print quality

Curved surfaces are approximated with straight-line segments before a model is sliced. Too few segments produce visibly faceted circles and spheres in the print; too many needlessly bloat the mesh and slow down evaluation for no visible benefit. The default, `.adaptive(minAngle: 2°, minSize: 0.15)`, is a reasonable starting point, but it can be tightened or loosened per-model or per-shape with `.withSegmentation(minAngle:minSize:)`. See <doc:Troubleshooting> for guidance on adjusting it.

## Per-part print settings

For multi-material or multi-setting prints, splitting a model into named parts lets each one carry its own settings — infill, speed, supports — in the slicer, rather than anything Cadova encodes directly. See <doc:WorkingWithParts>.

## Related Reading

- <doc:Examples> for a complete circular-overhang model.
- <doc:EnvironmentConcepts> for how environment values like tolerance and overhang angle propagate.
- <doc:WorkingWithParts> for splitting a model for per-part print settings.
- <doc:Troubleshooting> for segmentation and performance tuning.
