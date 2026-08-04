# Bending and Deforming

Twist, wrap, bend and soften geometry by moving its points around, rather than by moving the space it sits in.

## Overview

Transformations move the coordinate frame. Straight lines stay straight, parallel lines stay parallel, and the shape itself is untouched: only its placement changes. The operations on this page do something categorically different. They move each point of the mesh individually, so straight edges bend, flat faces curve, and the shape genuinely changes.

That one difference explains everything else about them. A deformation can only move points that *already exist*, so a box with eight corners and nothing in between has nothing to bend. Every built-in deformation therefore does the same three things:

1. Refine the mesh, subdividing it until its edges are short enough that the result will look smooth
2. Move every point through a function
3. Simplify the result, merging back the detail that turned out not to be needed

The refinement step is sized from the environment's segmentation settings, so <doc:EnvironmentConcepts> is what ultimately controls how good a deformation looks. The one exception is `.warped(...)`, the raw building block at the bottom of this page, which moves points and nothing else. If you call that one yourself, refining first is your job.

These operations are also more expensive than transformations, for the same reason: a transform rewrites one matrix, while a deformation touches every vertex of a mesh that it has just made denser.

## Twisting

`.twisted(by:)` rotates each point around the Z axis in proportion to its height, so the angle you give is the total twist from the bottom of the geometry to the top:

```swift
bar.twisted(by: 120°)
```

![A straight ribbed bar beside an identical bar whose ribs spiral around it after a 120 degree twist](bending-and-deforming-twisted)

The span comes from the geometry's own bounding box, so the twist always spreads across the whole shape and moving it in Z changes nothing.

`.twisted(by:per:)` states a rate instead, so the same call gives the same helix whatever the height, and a part that grows keeps its pitch rather than winding tighter:

```swift
bar.twisted(by: 30°, per: 10)   // 30° of twist for every 10 mm of height
```

Because that rate comes entirely from the arguments, its twist is zero at `z = 0` rather than at the bottom of the shape, so translating the geometry in Z rotates the result. Move it to the origin first if you want it to pivot elsewhere.

## Wrapping around a cylinder, circle or sphere

The wrapping operations reinterpret flat geometry in polar or spherical coordinates. They are the most useful deformations in the set and the easiest to get backwards, because everything depends on which axis becomes what.

`.wrappedAroundCylinder(diameter:)` takes 3D geometry lying flat and rolls it into a tube:

- **X** becomes the angle around the Z axis, counter-clockwise
- **Y** becomes the height
- **Z** becomes radial thickness, measured outward from the inner surface

```swift
strip.wrappedAroundCylinder(diameter: 30)
```

![A flat strip carrying a row of raised blocks, and the ring it becomes once wrapped, with the blocks now radiating outward around the circumference](bending-and-deforming-wrapped)

Omit the diameter and it is inferred from the geometry's X extent, treating that width as exactly one full turn. That is what makes the strip above close into a complete ring without you working out its circumference. Wrapping starts at the origin, which becomes 0° at the inner radius.

`.wrappedAroundCircle(radius:)` is the 2D counterpart, where **X** becomes the angle and **Y** becomes the radius. It wraps *clockwise*, which is the opposite of the usual convention, chosen so the wrapped result faces upward. There is a `diameter:` form, and a `spanning:` form that takes a `Range<Angle>` and works out the radius needed to fit the geometry into that arc:

```swift
label.wrappedAroundCircle(spanning: -30°..<30°)
```

`.wrappedAroundSphere(radius:)` maps **X** to longitude, **Y** to latitude and **Z** to radial distance, with Y = 0 at the equator. Because the Y range is spread across the full 180° from pole to pole, geometry whose Y extent is not symmetric about zero will stretch unevenly.

## Following a curve

`.following(path:)` bends geometry so that its long axis runs along a curve, stretching it to the curve's full length. In 3D the geometry's local Z follows the path; in 2D its local X does.

```swift
bar.following(path: path, pointing: .positiveX, toward: .direction(.positiveX))
```

![A straight rectangular bar beside the same bar bent into a tall S-curve after following a Bézier path](bending-and-deforming-following)

The `pointing:toward:` form controls roll. You name a direction in the geometry's own cross-section and a ``ReferenceTarget`` it should keep facing, and the geometry is reoriented continuously along the path to satisfy that. Without it, a path that curves in three dimensions will roll the geometry in ways you did not ask for. The rate of that reorientation is capped by `maxTwistRate` in the environment.

This is not the same operation as `.swept(along:)` in <doc:CurvesAndPaths>, though the results can look similar. Sweeping takes a 2D profile and builds a new solid by dragging it along a path. Following takes a solid that already exists and bends it. Reach for sweeping when the cross-section is the thing you have, and for following when the finished shape is.

`.deformed(by:)` is a third idea again. It reads a ``ParametricCurve`` as an offset *function* rather than as a route to travel: in 2D the curve is `y(x)`, and in 3D it is `(dx(z), dy(z))`. Each point is displaced by the curve's value at its own position along the driving axis, which gives smooth bends and tapers without stretching anything to a new length. The curve has to be monotonic along that axis, or the operation traps.

## Draping over a Bézier patch

`.deformed(by: BezierPatch)` maps flat geometry onto a curved surface. The geometry's X/Y bounding box is normalized to the patch's UV space, the patch supplies the new position, and the original Z is stacked on top of the patch surface as thickness:

```swift
Box([40, 40, 2])
    .deformed(by: patch)
```

This is how you give a flat panel a compound curve, or lay a pattern over a sculpted surface.

## Attracting and pulling

These operations move points toward a target instead of along an axis. `.pulled(toward:distance:)` is the simple form, accepting a point, a ``Line3D`` or a ``Plane``, and moving every point of the geometry that far toward it. Points already closer than `distance` land exactly on the target, which is what makes it useful for tapering a shape to a point or flattening one against a plane.

`.attracted(toward:influenceRadius:maxMovement:falloff:)` is the general version, and the extra parameters are what make it controllable:

```swift
Sphere(diameter: 44)
    .attracted(toward: [0, 0, 52], influenceRadius: 60, maxMovement: 26)
```

![A plain sphere beside the same sphere drawn up into a teardrop after being attracted toward a point above it](bending-and-deforming-attracted)

`influenceRadius` is the distance beyond which points are left alone, `maxMovement` caps how far any point may travel, and `falloff` is a ``ShapingFunction`` mapping relative distance to strength. It defaults to `.smoothstep`, which is what gives the taper above its soft shoulder; pass `nil` for full strength everywhere inside the radius. `.pulled(toward:distance:)` is exactly this call with an unlimited radius and no falloff.

## Skewing by the corners

`.skewingCorners(_:)` deforms geometry by dragging the corners of its bounding box to new places and interpolating everything in between. It applies to any geometry, not just boxes, and corners you do not mention stay where they are:

```swift
Cylinder(diameter: 10, height: 5)
    .skewingCorners([
        .minXminYminZ: Vector3D(-3, 2, -4),
        .minXmaxYmaxZ: Vector3D(0, 11, 6)
    ])
```

The dictionary is keyed by `Box.Corner` and gives absolute positions. `.skewingCorners(relative:)` takes offsets from where each corner already is, which is usually what you want when nudging a shape by an amount rather than to a place. The 2D form spells its corners out as named parameters instead, `bottomLeft:`, `bottomRight:`, `topRight:` and `topLeft:`.

## Softening a whole shape

`.smoothed(strength:)` rounds off hard edges and corners across an entire model, taking a value from `0` for no change to `1` for maximum smoothing. Around `0.2` to `0.4` gives subtle softening; `0.6` and above visibly rounds the forms:

```swift
shape.smoothed(strength: 0.8)
```

![A sharp-edged box with a cylinder on top, beside a smoothed copy whose edges and corners have become soft and rounded](bending-and-deforming-smoothed)

This is a global sculpting control, not an edge treatment. It softens everything at once and gives you no say over which edges or what radius, so it suits organic and decorative shapes rather than parts that have to fit something. For a specific radius on specific edges, use the edge-shaping operations (`shapingEdges` with an `EdgeShape`, or an `EdgeProfile`) instead.

## Writing your own deformation

All of the above are built on `.warped(operationName:cacheParameters:transform:)`, which hands you each point and takes back where it should go:

```swift
shape.warped(operationName: "ripple", cacheParameters: amplitude, wavelength) {
    var point = $0
    point.z += sin(point.x * 360° / wavelength) * amplitude
    return point
}
```

There is also an `inout` form, if mutating the point in place reads better than returning a new one.

The two odd-looking parameters are a caching contract. Cadova identifies the operation by `operationName` plus `cacheParameters`, so that identical work is not repeated. This means those values must fully determine what the closure does: every value the closure captures and depends on has to appear in `cacheParameters`, or you will get a stale result from a previous call. Give distinct operations distinct names.

Remember that `.warped(...)` does not refine anything. Call `.refined(maxEdgeLength:)` first if your transform needs points that are not there yet, and `.simplified()` afterwards to discard the ones that turned out not to matter. A variant taking an `initialization:` closure lets you compute a lookup table once and share it across every point, which is how the curve-driven deformations avoid re-evaluating a curve millions of times.

`.scaled(along:operationName:scale:)` is a thin wrapper over this, varying the cross-section of a shape as a function of position along an axis.

## Controlling detail and cost

Deformation quality is a direct consequence of mesh density, so these are the levers:

- `.refined(maxEdgeLength:)` subdivides until no edge is longer than the value you give, adding points for a deformation to move
- `.simplified()` and `.simplified(threshold:)` remove points that contribute nothing, which is worth doing after a deformation rather than before
- `withSegmentation(...)` (see <doc:EnvironmentConcepts>) sets the resolution the built-in deformations derive their own refinement from
- `withMaxTwistRate(_:)` caps how quickly geometry may roll while following a path

A deformation applied to a coarse mesh produces a coarse result, and no amount of simplification afterwards recovers detail that was never there. If a wrap or a bend looks faceted, the fix is more refinement going in, not less simplification coming out.

## Related Reading

- <doc:Transformations> for the affine operations these complement, and for `.resized(...)` when you want a size rather than a shape change
- <doc:CurvesAndPaths> for building the paths and patches that drive several of these operations, and for `.swept(along:)`
- <doc:EnvironmentConcepts> for the segmentation settings that decide how smooth a deformation comes out
