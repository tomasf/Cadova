# Extrusion and Revolution

Give a 2D shape depth to build a 3D solid, and flatten a 3D solid back down to 2D.

## Overview

Many 3D models in Cadova start life as a 2D shape. *Extrusion* and *revolution* are the two fundamental ways to turn that flat profile into a solid: extrusion pushes it straight up to give it height, while revolution spins it around an axis to give it a circular form. Their counterpart, *projection*, runs in the opposite direction. It takes a finished 3D solid and collapses it back into a 2D shape, either as a silhouette or as a cross-section.

Together these operations are the bridge between 2D and 3D. They pair naturally with the 2D shapes described in <doc:GeometryConcepts> and the paths in <doc:CurvesAndPaths>: you draw a profile once, then extrude or revolve it into the solid you actually want.

If your profile needs to follow a curved trajectory rather than a straight line or a circle, reach for `.swept(along:)` or `Loft` instead. Both are described in <doc:CurvesAndPaths>.

## Extruding a shape

`.extruded(height:)` takes any ``Geometry2D`` and pushes it straight up along the Z axis, producing a prism whose cross-section is the original shape:

```swift
Circle(radius: 10)
    .extruded(height: 4)
```

That gives a flat disc, the same thing a ``Cylinder`` would produce, but starting from a 2D profile you can build up however you like.

Extrusion becomes more interesting with its two optional parameters. `twist` gradually rotates the cross-section around the Z axis as it rises, and `topScale` scales it from full size at the bottom to a different size at the top. Combining them turns a simple profile into a sculpted column:

```swift
Rectangle(24)
    .aligned(at: .center)
    .rounded(radius: 5)
    .extruded(height: 44, twist: 120°, topScale: [0.55, 0.55])
```

![A rounded square extruded upward with a 120° twist while tapering to 55% of its width](extrusion-and-revolution-extruded)

When a twist is applied, the number of vertical divisions is derived from the current segmentation environment, so a more finely segmented model produces a smoother twist. See <doc:EnvironmentConcepts> for how to control segmentation.

A related form, `.extruded(height:topEdge:bottomEdge:)`, rounds or chamfers the top and bottom edges as part of the extrusion, using an ``EdgeProfile``. It's a convenient way to soften the rim of an extruded shape without a separate operation.

## Revolving a profile

`.revolved(in:)` sweeps a 2D profile around the Z axis to form a solid of revolution. It's the natural way to model anything rotationally symmetric, like a vase, bowl, knob, or turned leg.

The profile is taken from the part of the shape lying on or to the right of the Y axis (positive X); anything with negative X is ignored. You can think of the positive X axis as the radius and the Y axis as the height. By default the profile is swept a full turn, but passing a smaller `Range<Angle>` produces a partial revolution:

```swift
let profile = BezierPath2D {
    line(x: 16, y: 0)
    curve(controlX: 17, controlY: 9,  endX: 7,  endY: 20)
    curve(controlX: 3,  controlY: 33, endX: 14, endY: 44)
    curve(controlX: 17, controlY: 51, endX: 10, endY: 58)
    line(x: 0, y: 58)
}

profile.filled()
    .revolved(in: 0°..<270°)
```

![A curved profile revolved 270° around the Z axis, forming a turned finial with a wedge left open to reveal that it's solid](extrusion-and-revolution-revolved)

Here the revolution stops at 270°, leaving a wedge open so you can see that the result is a solid body of revolution. Use a full `0°..<360°` (the default) for a closed solid, or a partial range to create segments and open forms.

## Projecting to a silhouette

Projection is the inverse of extrusion: instead of adding depth, it removes it. `.projected()` flattens a 3D solid straight down onto the XY plane, producing the 2D outline you'd see looking at it from directly above, its silhouette. Internal detail is discarded; only the outer boundary remains.

```swift
solid.projected()
```

![A solid cylinder floating above its flattened silhouette, a solid disc, on the ground plane](extrusion-and-revolution-projected)

The image shows a cylinder that has a hidden spherical cavity inside it, floating above the 2D shape its projection produces. Because projection keeps only the outer silhouette, the enclosed cavity leaves no trace: the result is a plain, solid disc.

This is a purely geometric, orthographic projection, so there's no perspective or foreshortening. A common use is to derive a flat base or footprint from an existing 3D part, then extrude it back up to a different height or offset it outward.

To project onto a plane other than the XY plane, use `.projected(onto:)`. This gives you orthographic views from any direction. For example, a side view onto the YZ plane:

```swift
Box(10).projected(onto: .yz)
```

## Slicing a cross-section

Where projection flattens the *whole* solid into its silhouette, slicing cuts it at a single plane and returns just that cross-section. `.sliced(atZ:)` intersects the geometry with a horizontal plane at the given height and hands back the resulting 2D shape:

```swift
solid.sliced(atZ: 0)
```

![The same cylinder floating above its cross-section at mid-height, a ring, revealing the internal cavity](extrusion-and-revolution-sliced)

This is the same hollow cylinder as before, but slicing tells a very different story than projecting it did. The cut passes through the middle of the internal cavity, so the cross-section is a ring: unlike the silhouette, a slice reveals interior structure the outline hides. Comparing the two images side by side is the clearest way to understand the difference: projection gives the outer shadow, while slicing gives what a saw would expose at that height.

For a cut along an arbitrary orientation rather than a horizontal one, `.sliced(along:)` takes a ``Plane``, giving you a cross-section at any angle and position.

## Reading the source alongside the result

Each of the projection and slicing methods has a builder variant that hands you *both* the original 3D geometry and the 2D result, so you can compose them together. This is exactly how the illustrations above place the solid above its flattened output:

```swift
solid.sliced(atZ: 0) { body, section in
    body.translated(z: 40)
    section.extruded(height: 1)
}
```

The same pattern is available as `.projected { body, silhouette in … }`, `.projected(onto:) { … }`, and `.sliced(along:) { … }`. It's useful whenever the geometry you're building depends on both the solid and the flat shape derived from it, such as annotating a part with its own footprint, or building a lid that matches a cross-section.
