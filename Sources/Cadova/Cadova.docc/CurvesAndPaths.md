# Curves and Paths

Build 2D paths with BezierPath, then follow them with Sweep and Loft to create 3D shapes.

## Overview

Several of Cadova's most powerful 3D operations are built on a shared idea: a path through space that other geometry can follow. `.swept(along:pointing:toward:)` extrudes a 2D shape along such a path to form a pipe or rail; `Loft` interpolates between 2D cross-sections placed along one to form a smooth, tapered solid. Both are driven by a ``ParametricCurve``, a curve sampled by a single parameter that produces a position and tangent direction at every point along it.

``BezierPath`` is the curve type you'll reach for most often, so most of this article's examples use it, but it's not the only option. Cadova also provides ``InterpolatingCurve`` and ``SplineCurve``, described further down in "Other curve types". All three conform to `ParametricCurve`, which is what makes any of them usable as the path for `Sweep` and `Loft`, or anywhere else a curve is expected.

## Building a BezierPath

``BezierPath2D`` and ``BezierPath3D`` represent a sequence of connected Bezier curves. The most direct way to build one is to start at a point and chain `addingLine(to:)`, `addingQuadraticCurve(controlPoint:end:)`, or `addingCubicCurve(controlPoint1:controlPoint2:end:)`:

```swift
let path = BezierPath2D(startPoint: [0, 0])
    .addingLine(to: [10, 0])
    .addingQuadraticCurve(controlPoint: [15, 0], end: [15, 10])
```

For longer or more intricate paths, the declarative builder syntax is usually more readable. It uses global functions like `line(x:y:)`, `curve(controlX:controlY:endX:endY:)`, and `clockwiseArc(center:angle:)`:

```swift
let path = BezierPath2D(from: [0, 0]) {
    line(x: 20, y: 0)
    curve(controlX: 30, controlY: 0, endX: 30, endY: 10)
    line(x: 30, y: 30)
}
```

By default, coordinates are absolute positions in the coordinate system. Passing `mode: .relative` interprets them as offsets from the current point instead, which is often more convenient for procedurally generated or repetitive paths:

```swift
let path = BezierPath2D(from: [0, 0], mode: .relative) {
    line(x: 20, y: 0)
    line(x: 0, y: 10)
    line(x: -20, y: 0)
}
```

`BezierPath3D` works the same way, with 3D builder functions that take X, Y, and Z coordinates:

```swift
let path = BezierPath3D(from: [0, 0, 0]) {
    line(x: 0, y: 0, z: 20)
    curve(
        controlX: 10, controlY: 0, controlZ: 30,
        endX: 20, endY: 0, endZ: 40
    )
}
```

## Other curve types

``BezierPath`` is defined by control points that pull the curve toward them without the curve necessarily passing through them, the usual way to think about Bezier curves. Cadova also provides two alternatives with different tradeoffs:

``InterpolatingCurve`` takes a list of points and produces a smooth Catmull–Rom spline that passes *through* every one of them, which is often more intuitive than placing Bezier control points by hand:

```swift
let path = InterpolatingCurve(through: [
    [0, 0, 0],
    [10, 5, 5],
    [20, 0, 15],
] as [Vector3D])
```

If the first and last points coincide, the curve is automatically treated as closed, with a smooth seam rather than a cusp.

``SplineCurve`` is a full NURBS (non-uniform rational B-spline) curve, giving you low-level control over degree, knot vector, and per-control-point weights. Most of the time, the convenience constructors are enough:

```swift
let path = SplineCurve.uniformCubic(controlPoints: [
    [0, 0, 0],
    [10, 5, 5],
    [20, 0, 15],
] as [Vector3D])
```

Unlike `InterpolatingCurve`, a spline's control points shape the curve without the curve necessarily passing through them (the same relationship `BezierPath`'s control points have to it) — reach for `SplineCurve` when you need the mathematical precision of NURBS, such as matching a curve defined in other CAD software.

## Turning a 2D curve into a shape

A 2D curve isn't only useful as a path to sweep or loft along, it can also become a solid shape directly. `.filled()` samples the curve and fills its interior:

```swift
let path = BezierPath2D(startPoint: [0, 0])
    .addingCubicCurve(controlPoint1: [10, 65], controlPoint2: [55, -20], end: [60, 40])

path.filled()
```

![The filled interior of a self-intersecting cubic Bezier curve](curves-and-paths-filled)

This works for any of the curve types described above, not just `BezierPath` — `InterpolatingCurve<Vector2D>` and `SplineCurve<Vector2D>` can be filled the same way.

A curve doesn't need to be closed to become geometry, either. `.stroked(width:alignment:style:)` samples the curve into a polyline and expands it into a filled outline of the given thickness — useful for open paths like a wire or a routed channel, where `.filled()` wouldn't make sense:

```swift
path.stroked(width: 2, style: .round)
```

![The same curve, stroked with a round cap and rounded joins](curves-and-paths-stroked)

`alignment` controls whether the stroke is centered on the curve or offset to one side, and `style` controls how corners are joined (`.miter`, `.round`, or `.bevel`).

## Sweeping a shape along a path

`.swept(along:pointing:toward:)` extrudes a 2D shape along a 3D path, producing a continuous solid — useful for pipes, rails, bent sheets, or any geometry that follows a curved trajectory:

```swift
Circle(diameter: 4)
    .swept(along: path, pointing: .down, toward: .direction(.negativeZ))
```

![A circle swept along a bent 3D path, forming a bent pipe](curves-and-paths-swept)

Because the shape can rotate freely as it travels along the path, Cadova needs to know how to orient it at each point and that's what `pointing` and `toward` control:

- `pointing` is a direction *within* the 2D shape being swept — usually `.down` or `.right` — that should be kept facing toward `target`.
- `toward` is a ``ReferenceTarget`` describing what that direction should point toward: `.direction(_:)` for a fixed world direction, `.point(_:)` for a fixed point, or `.line(_:)` for a fixed line.

There's no universally sensible default for these. What looks natural for a roughly horizontal path (facing gravity-down) can be degenerate for a vertical one, so both must be specified explicitly. The rate at which the shape is allowed to twist between samples is limited by ``EnvironmentValues/maxTwistRate``; see <doc:EnvironmentConcepts> and ``Geometry/withMaxTwistRate(_:)``.

## Lofting between cross-sections

`Loft` interpolates between a series of 2D cross-sections, filling in the space between them to form a smooth 3D shape:

```swift
Loft(interpolation: .easeInOut) {
    Section(at: 0) {
        Circle(diameter: 20)
    }
    Section(at: 30) {
        Rectangle(20).aligned(at: .center)
    }
}
```

![A loft transitioning from a circle to a square](curves-and-paths-loft)

Each `Section(at:)` specifies a distance and a 2D shape. With no explicit path, sections stack along an implicit straight vertical (Z) axis, and the distance is simply the Z height — as in the example above. All sections must have compatible topology: the same number of top-level shapes, with the same number of holes in each, and so on.

By default, adjacent sections are connected by resampling and interpolating between their outlines, using a ``ShapingFunction`` to control the pacing — `.linear`, `.easeInOut`, `.smootherstep`, and more are available. This is set for the whole loft via `interpolation`, and can be overridden per section.

### Lofting along a path

Just like `Sweep`, `Loft` can follow an arbitrary 3D path instead of an implicit straight vertical axis. In this form, `Section(at:)` distances are measured as arc length traveled along the path, and each cross-section is automatically oriented using the same `pointing`/`toward` model described above:

```swift
Loft(along: path, pointing: .down, toward: .direction(.negativeZ)) {
    Section(at: 0) {
        Circle(diameter: 20)
    }
    Section(at: 40) {
        Rectangle(20).aligned(at: .center)
    }
}
```

![A loft from a circle to a square, following the same bent path](curves-and-paths-loft-path)

## Related Reading

- <doc:Examples> for complete swept-text and loft models.
- <doc:EnvironmentConcepts> for how segmentation and twist rate affect curve sampling.
