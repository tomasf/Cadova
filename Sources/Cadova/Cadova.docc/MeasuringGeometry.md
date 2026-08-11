# Measuring Geometry

Evaluate a shape, read back its size and other properties, then build new geometry from what you find.

## Overview

Most of the time you build geometry from numbers you already know: a box is 20 mm wide because you typed `20`. Sometimes, though, you need to react to what a shape actually turns out to be after it's been assembled. How wide is this composite once everything is combined and rotated? What's its volume? Where is its center? Measuring answers those questions and lets you feed the answers straight back into more geometry.

The mental model is a two-step handoff. Cadova evaluates the shape, computes its measurements, and passes both the original geometry and the measurements to a closure you provide. Your closure returns new geometry that can use those values. Because the measurements describe the shape *after* all its operations have been applied, this happens when the model is built rather than immediately, but you never deal with that directly: you just read the values in the closure.

This is the same machinery that powers alignment. When you write `.aligned(at: .center)` (see <doc:AlignmentAndStacking>), Cadova measures the geometry's bounding box and translates it for you. Measuring exposes that capability directly so you can do your own positioning and sizing.

## Reacting to a shape's size

The most common thing to measure is the *bounding box*: the smallest axis-aligned box that fully encloses a shape. `.measuringBounds(_:)` hands you that box, so you can size or place other geometry to match.

To simply *see* a shape's bounding box, Cadova has a built-in debugging overlay, `.visualizingBounds()`, which draws the box as a thin frame around the geometry:

```swift
someShape.visualizingBounds()
```

![An irregular composite of a box, cylinder, and sphere inside the blue frame drawn by visualizingBounds](measuring-bounds-cage)

The blue frame above hugs the composite no matter how its pieces are sized or rotated. Its thickness and color follow the visualization environment, which you can adjust with `withVisualizationScale(_:)` and `withVisualizationColor(_:)`. A ``BoundingBox`` gives you everything you need to work with it directly:

- `minimum` and `maximum`, the two opposite corners
- `size`, the box's dimensions as a vector
- `center`, the point halfway between the corners
- `box[.x]`, `box[.y]`, `box[.z]`, the coordinate range along one axis

It also offers `offset(_:)` to grow or shrink the box, `intersection(with:)` to find where it overlaps another box, and `contains(_:)` to test whether a point falls inside.

A practical use is fitting one part to another. Here a base plate is sized to the footprint of whatever sits on it, plus a margin, and dropped underneath:

```swift
someShape.measuringBounds { shape, box in
    shape
    Box([box.size.x + 8, box.size.y + 8, 3])
        .aligned(at: .centerXY, .top)
        .translated(x: box.center.x, y: box.center.y)
}
```

![The same composite resting on a rectangular base plate automatically sized to its footprint with a margin](measuring-fitted-base)

If the shape might be empty, `.measuringBounds(_:)` won't have a box to give you. You can supply a fallback with its trailing `empty:` closure, which runs when there are no bounds.

## Reading other properties

When you need more than the bounding box, `.measuring(_:)` passes a full ``Measurements`` value. Which properties are available depends on whether the geometry is 2D or 3D.

For 2D geometry you get `area`, `contourCount` (the number of closed paths), `isConvex`, `pointCount`, `isEmpty`, and the `boundingBox`. For example, only hatch a region if it's large enough to be worth it:

```swift
region.measuring { shape, measurements in
    shape
    if measurements.area > 100 {
        hatchLines
    }
}
```

For 3D geometry you get `volume`, `surfaceArea`, `edgeCount`, `triangleCount`, `pointCount`, `isEmpty`, `partCount`, and the `boundingBox`.

By default, measurements cover the main geometry together with its solid (printable) parts. Pass a ``MeasurementScope`` to change that: `.mainPart` measures only the main geometry, while `.allParts` includes context and visual parts too. Parts are a 3D concept (see <doc:WorkingWithParts>), so the scope has no effect on 2D geometry.

## Handling empty geometry

Empty results are common when a step might remove everything, such as an intersection that doesn't overlap. `.ifEmpty(_:)` substitutes a replacement only when the geometry has nothing in it:

```swift
maybeEmpty.ifEmpty {
    Cylinder(diameter: 2, height: 10)   // a visible marker instead of nothing
}
```

## Measuring several shapes together

To relate multiple geometries to one another, the free function `measureBounds(of:)` measures a whole array at once and hands you their boxes in order. Each entry is optional, since any of the shapes might be empty:

```swift
measureBounds(of: [partA, partB]) { boxes in
    // boxes is [BoundingBox3D?], one per input
    // ...position or size something based on all of them
}
```

## Reading outlines and surfaces

Two more focused readers go beyond aggregate measurements.

`.readingOutlines(_:)` samples a 2D shape's boundary and gives you its contours as closed ``BezierPath2D`` values, ready to follow, stroke, or distribute geometry along:

```swift
shape.readingOutlines { shape, outlines in
    shape
    // outlines is [BezierPath2D], one per contour
}
```

`.readingSurfaces(from:in:)` casts a ray through a 3D solid and reports every surface it crosses as a ``SurfaceCrossing``, each carrying a `position`, `normal`, `distance`, and a `transition` telling you whether the ray is `.entering` or `.exiting` the solid there. This is how you find where a feature should sit on an irregular surface. `.readingFirstSurface(from:in:)` is the same idea when you only care about the first hit:

```swift
solid.readingFirstSurface(from: [0, 0, 100], in: .down) { solid, crossing in
    solid
    if let crossing {
        Sphere(radius: 2)
            .translated(crossing.position)
    }
}
```
