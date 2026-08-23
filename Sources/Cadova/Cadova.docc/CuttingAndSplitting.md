# Cutting, Splitting and Masking

Cut geometry with a plane, clip it to a region, take both halves apart, or change one area of a shape and leave the rest alone.

## Overview

Subtraction removes material. The operations on this page do something different: they pick out a *region of space* and then decide what happens to the geometry inside it. That covers slicing a model in half to print it, keeping only the part of a profile you want, cutting a display cross-section, and rounding one corner of a shape without touching the others.

They look like a scattered handful of methods, but there are really only two choices to make. First, how you name the region:

- A ``Plane`` in 3D or a ``Line2D`` in 2D, which divides all of space in two
- Axis-aligned ranges, such as "everything above z = 10" or "the slab between x = 2 and x = 8"
- Another piece of geometry, used as a *mask*

Then, what you want done with it:

- Keep the inside and discard the rest, with `.trimmed(along:)` or `.within(...)`
- Get both sides back as separate geometry, with `.split(...)`
- Keep the whole shape but change only what falls inside, with `.within(...) { }` or `.whileMasked(using:do:)`

Every method below is one cell of that grid. Once you know which row and which column you need, the name follows.

## Trimming to one side

`.trimmed(along:)` cuts with an infinite plane or line and keeps one side. The side it keeps is worth committing to memory, because there is nothing in the call to remind you:

- In 3D, it keeps the side the plane's **normal** points toward
- In 2D, it keeps the **clockwise** side of the line, meaning the right-hand side relative to the line's direction

```swift
Sphere(diameter: 20).trimmed(along: .z(0))   // the top half
Circle(diameter: 20).trimmed(along: .y)      // the right half
```

If you got the wrong side, `.flipped` reverses either value rather than making you rebuild it:

```swift
Sphere(diameter: 20).trimmed(along: Plane.z(0).flipped)   // now the bottom half
```

Planes are built by `.x(_:)`, `.y(_:)` and `.z(_:)` for the axis-aligned cases, by `Plane(perpendicularTo:at:)`, or by `Plane(point1:point2:point3:)` through three points. The `.xy`, `.xz` and `.yz` constants are the coordinate planes through the origin, and `.offset(_:)` slides a plane along its own normal, which is handy for nudging a cut off a face. Lines have the same shape of API, with `Line2D.x` and `.y` as the axes and `Line2D(point:direction:)` for anything else.

## Clipping to a region

When the boundary you want is axis-aligned, you do not need a plane at all. `.within(...)` takes ranges and keeps whatever falls inside them:

```swift
shape.within(0..., along: .z)          // everything at or above z = 0
shape.within(z: 0...)                  // the same thing
shape.within(x: -10...10, z: ...25)    // a slab in X, capped in Z
```

Any Swift range expression works, including partial and infinite ones, so `0...`, `...10` and `2..<8` are all valid. Axes you leave out stay unbounded. Two bounded axes give you a slab, three give you a box.

## Getting both halves

`.split(...)` cuts once and hands you *both* results, so you can treat them differently instead of throwing one away. The closure receives two geometries and returns whatever you build from them:

```swift
blob.split(along: .z(2)) { over, under in
    over.colored(.darkOrange)
        .translated(z: 7)

    under.colored(.steelBlue)
        .translated(z: -3)
}
```

![A lumpy solid cut by a horizontal plane, with the orange upper half lifted clear of the blue lower half](cutting-and-splitting-split)

The first geometry is the side the plane's normal faces, matching `.trimmed(along:)`. The same method takes ranges instead of a plane, and there is a variant that takes an arbitrary mask so the boundary can be any shape you like:

```swift
shape.split(z: 0...) { above, below in
    above.colored(.darkOrange)
    below
}

shape.split {
    CuttingBlock()
} result: { inside, outside in
    inside.colored(.darkOrange)
    outside
}
```

When you need both halves inside async code rather than inside a geometry tree, `GeometryEvaluator.split(_:along:)` (and its mask- and range-based counterparts) gives you the same two parts as a tuple instead of a closure.

## Splitting a model for printing

Cutting a tall model in half so both pieces fit the build volume is common enough to have its own method. `.split(along:arrangingPartsAlong:)` cuts, rotates each half so its cut face lies flat, and arranges the pieces side by side:

```swift
blob.split(along: .z(2), arrangingPartsAlong: .x, spacing: 6)
```

![Two halves of a solid standing side by side on a common baseline, each resting on its flat cut face](cutting-and-splitting-print-halves)

`flipped: true` turns the cut faces up instead of down, and `spacing:` controls the gap, which defaults to 3 mm. See <doc:DesigningFor3DPrinting> for the rest of the print-oriented toolkit.

## Changing only part of a shape

The last row of the grid keeps the whole shape and changes only what falls inside the region. Two operations do this, and the difference between them is the one thing on this page worth reading twice. Both begin the same way, by removing the region from the original. They differ in what the closure is handed, and in what happens to what it gives back.

### Taking the piece out and putting it back

`.within(...) { }` hands the closure the **clipped region**, and adds whatever comes back exactly as it stands. Nothing re-clips the result, so the operation is free to move material right out of the region:

```swift
Cylinder(diameter: 24, height: 40)
    .within(z: 14...26) {
        $0.scaled(x: 1.45, y: 1.45)
    }
```

![A tall cylinder with a wider flared band in its middle third, the rest unchanged](cutting-and-splitting-within)

Read it as: cut this slice out, do something to the slice, union the result back in. If the closure translates the slice ten millimeters sideways, that is where it ends up.

### Changing the whole shape and showing it through a window

`.whileMasked(...)` hands the closure the **whole geometry**, and intersects the result with the region before putting it back. Nothing can escape the mask, and anything the closure produces outside it is discarded.

That is more restrictive, and it is exactly what makes shape-wide operations work on a single feature:

```swift
// Severs the point first, then rounds it, fresh cut edge and all
star.within(x: 8...) {
    $0.rounded(outsideRadius: 2.5)
}

// Rounds the whole star, then shows only this one point of it
star.whileMasked(x: 8...) {
    $0.rounded(outsideRadius: 2.5)
}
```

![Two five-pointed stars: the blue one on the left has its right point severed into a detached rounded blob, while the orange one on the right has that point smoothly rounded and still attached](cutting-and-splitting-within-vs-masked)

Both calls name the same region and run the same operation, and the image shows what the difference costs. The point on the left has come away from the body, because the cut edge that `.within` created got rounded along with everything else. On the right the corner is rounded correctly and the point is still attached to the star.

The mask does not have to be a range. The `using:` form takes arbitrary geometry, which is how you select a feature that no combination of axis bounds would isolate:

```swift
star.whileMasked {
    Circle(diameter: 20).translated(x: 17)
} do: {
    $0.rounded(outsideRadius: 2.5)
}
```

Pass `inverted: true` to act everywhere *except* inside the mask.

So: reach for `.within(...) { }` when you want to relocate or replace a section, and `.whileMasked(...)` when the operation needs to see the whole shape to produce the right answer. Since both accept ranges and only `.whileMasked` accepts a mask, it is what the closure sees, not how you spell the region, that separates them.

## Separating into parts

`.separating(...)` splits and hands one side to a named ``Part`` rather than returning it to you. The detached side becomes a separate object in the exported 3MF, which makes it a clean way to publish a cross-section view or to give one piece its own slicer settings:

```swift
let topHalf = Part("Top Half")

model.separating(along: .z(0), into: topHalf)

model.separating(into: Part("Core")) {
    Box([10, 10, 2]).translated(z: 1)
}
```

The side facing the plane's normal is the one that moves into the part. Because it is detached, it no longer takes part in booleans or modifiers applied afterwards, though it still follows transformations applied to the whole. See <doc:WorkingWithParts> for what parts are and how they reach the exported file.

## Pulling apart disconnected pieces

The operations above cut geometry that was whole. `.separated(_:)` does the opposite: it finds the pieces that are *already* disconnected and gives them to you as an array, in no particular order.

```swift
model.separated { components in
    Stack(.x, spacing: 2) {
        components
    }
}
```

This is how you take a shape that fell into several shells and lay the shells out, count them, or keep only some. The closure can return a different dimensionality than it received, so a 3D model can be separated and turned into a 2D drawing. When you need the components inside async code rather than inside a geometry tree, `GeometryEvaluator.components(of:)` gives you the same result.

## Related Reading

- <doc:MeasuringGeometry> for reading a shape's bounds first, so a cut can be placed relative to what is actually there
- <doc:ExtrusionAndRevolution> for `.projected()` and `.sliced(...)`, which flatten 3D into 2D rather than cutting within a dimension
- <doc:WorkingWithParts> for what happens to geometry once `.separating(...)` hands it to a part
- <doc:DesigningFor3DPrinting> for the print-oriented reasons to cut a model up in the first place
