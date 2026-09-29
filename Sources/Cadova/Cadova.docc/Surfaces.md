# Surfaces

Build curved sheets from curves or grids of points, and turn them into solids.

## Overview

A surface is a curved sheet with no thickness. Cadova models always have volume, so a surface is never used on its own: you either enclose it into a solid, or drape other geometry over it.

Cadova has five kinds of surface. They differ in what you give them and whether the surface passes through it:

| Surface | You give it | Passes through your input |
|---|---|---|
| ``RuledSurface`` | Two curves | Both curves |
| ``CoonsPatch`` | Four curves forming a closed loop | All four curves |
| ``InterpolatingSurface`` | A grid of points | Every point |
| ``BezierPatch`` | A small grid of control points | The corner points only |
| ``SplineSurface`` | A grid of control points, optionally weighted | The corner points only |

Use a curve-based surface when you know the shape of the edges, ``InterpolatingSurface`` when you know points the surface must hit, and ``BezierPatch`` or ``SplineSurface`` when you want to sculpt freely with control points.

In the pictures on this page, the surface is orange, and the thin gray lines and dots mark the curves and points it was built from. They aren't part of the code samples.

## Surfaces from curves

``RuledSurface`` connects two curves with straight lines. Each point on the first curve is joined to the point the same fraction of the way along the second, measured by length:

```swift
let straight = BezierPath3D(linesBetween: [[0, 0, 0], [60, 0, 0]])
let wave = BezierPath3D(from: [0, 16, 12]) {
    curve(
        controlX: 20, controlY: 34, controlZ: -4,
        controlX: 40, controlY: 0, controlZ: 26,
        endX: 60, endY: 16, endZ: 2
    )
}

RuledSurface(from: straight, to: wave)
    .enclosed(offset: [0, 0, 1])
```

![A thin orange sheet spanning a straight gray line at the front and a wavy gray curve at the back, twisting as it follows the wave](surfaces-ruled)

This is the shape to use for twisted strips and transitions between two edges.

``CoonsPatch`` fills the area bounded by four curves, and runs exactly along all of them. Give the curves in order around the boundary, each starting where the previous one ends:

```swift
CoonsPatch(boundary: front, right, back, left)
    .enclosed(offset: [0, 0, 1])
```

![A saddle-shaped orange sheet whose front and back edges bow upward and whose sides bow downward, outlined by its four gray boundary curves](surfaces-coons)

You place no points inside the patch; the edges alone decide its shape. If the curves don't form a closed loop, creating the patch stops with an error naming the edges that don't meet.

Both types take any curve, including 2D curves (which lie in the XY plane), and the curves don't need to be of the same kind.

## Surfaces from points

``InterpolatingSurface`` passes through every point of a grid. Give it the points as rows:

```swift
let heights: [[Double]] = [
    [2, 3, 4, 3, 2],
    [3, 7, 10, 6, 3],
    [4, 10, 14, 8, 4],
    [2, 5, 7, 9, 5],
]
let grid = heights.enumerated().map { row, values in
    values.enumerated().map { column, z in
        Vector3D(Double(column) * 10, Double(row) * 10, z)
    }
}

InterpolatingSurface(through: grid)
    .enclosed(against: .z(-3))
```

![An orange tile with a smooth hill on top, and gray spheres marking the grid points, each sitting exactly on the surface](surfaces-interpolating)

Use it when you know where the surface has to be, such as heights you measured or calculated.

``BezierPatch`` and ``SplineSurface`` work the other way around. Their control points pull on the surface without it passing through them, which gives smooth shapes that are easy to adjust. A Bézier patch is a single small grid, where every control point affects the whole surface. A spline surface can have a large grid, where each control point only affects the area near it. `uniformCubic` is the usual way to make one:

```swift
let controlPoints: [[Vector3D]] = (0..<4).map { row in
    (0..<6).map { column in
        let z: Double = (row + column).isMultiple(of: 2) ? 0 : 12
        return Vector3D(Double(column) * 10, Double(row) * 10, z)
    }
}

SplineSurface.uniformCubic(controlPoints: controlPoints)
    .enclosed(offset: [0, 0, -1])
```

![A wavy orange sheet below a gray net of control points alternating between low and high; the sheet follows the net loosely and touches it only at the corners](surfaces-spline)

## Turning a surface into a solid

Every surface can be enclosed in three ways:

- `enclosed(against:)` fills the space between the surface and a plane
- `enclosed(to:)` connects the surface's edges to a single point
- `enclosed(offset:)` adds a copy of the surface moved by an offset, and closes the gap between them

```swift
patch.enclosed(against: .z(-8))
patch.enclosed(to: [15, 15, -18])
patch.enclosed(offset: [0, 0, -3])
```

![The same saddle-shaped surface enclosed three ways: as a block down to a flat base, as a point-bottomed pyramid, and as a thin curved slab](surfaces-enclosed)

How finely a surface is divided into triangles follows the environment's segmentation, like any other curved shape. See <doc:EnvironmentConcepts>.

## Draping geometry over a surface

`draped(over:)` lays 3D geometry onto a surface. The geometry's X and Y are used directly as the surface's `u` and `v`, and its height is added on top, so you place a design on the surface by moving it.

The surface's domain sets the scale. A ``BezierPatch`` spans `0...1` in both directions, so remap it to its size with `remapped(u:v:)`:

```swift
let domed = patch.remapped(u: 0...40, v: 0...30)

Text("Cadova")
    .withFontSize(8)
    .withTextAlignment(horizontal: .center, vertical: .center)
    .extruded(height: 1.2)
    .translated(x: 20, y: 15)
    .draped(over: domed)
```

![Orange lettering reading Cadova at its normal size, centered on a gently domed gray surface and following its curve](surfaces-draped)

Geometry outside the domain is clamped to the surface's edge, with a warning. See <doc:BendingAndDeforming> for other ways to bend geometry.

## Related Reading

- <doc:CurvesAndPaths> for building the curves that ruled surfaces and Coons patches start from
- <doc:BendingAndDeforming> for other ways to reshape existing geometry
- <doc:EnvironmentConcepts> for the segmentation settings that control how smooth a surface comes out
