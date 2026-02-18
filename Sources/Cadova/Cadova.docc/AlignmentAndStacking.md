# Alignment and Stacking

Position geometry relative to the origin and arrange shapes along an axis.

## Overview

In Cadova, alignment is a way to control how geometry is positioned relative to the coordinate system's origin. Since different shapes are defined differently, some centered, some corner-based, aligning them explicitly is often the easiest way to place them where you want.

For example, a `Circle(radius: 10)` is centered at the origin by default, but a `Rectangle([20, 10])` extends from the origin toward the top right. Using alignment helps you standardize and simplify placement:

```swift
Rectangle([20, 10])
    .aligned(at: .centerX, .bottom)
```

This centers the rectangle along the X-axis and aligns its bottom edge with Y = 0.

## How `.aligned(at:)` works

The `.aligned(at:)` method repositions geometry by translating it so that parts of its *bounding box* align to the coordinate system origin, based on the criteria you provide. The geometry isn't clipped, resized, or modified, just moved so it aligns as requested. You can align any geometry, including complex compositions, boolean operations, or custom components.

You align along one or more axes:

```swift
Box([30, 40, 50])
    .aligned(at: .centerX, .maxY, .bottom)
```

This centers the box in X, moves the back to Y = 0, and aligns the bottom of the Z axis to Z = 0. If you provide multiple alignments for the same axis, the last one wins.

## Alignment Presets

Cadova provides a set of readable alignment constants so you don't need to manually calculate anything. These include:

- `.minX`, `.centerX`, `.maxX`, `.left`, `.right`
- `.minY`, `.centerY`, `.maxY`
- `.minZ`, `.centerZ`, `.maxZ`
- `.top`, `.bottom` (Y axis in 2D, Z axis in 3D)
- `.center` (all axes), `.centerXY`

## Practical Examples

### Center a rectangle

```swift
Rectangle([20, 10])
    .aligned(at: .center)
```

### Align the bottom (min Y) of a circle to the origin

```swift
Circle(radius: 10)
    .aligned(at: .bottom)
```

### Center a shape horizontally and align to the top

```swift
Rectangle([50, 20])
    .aligned(at: .centerX, .top)
```

## Stack

``Stack`` is a container that arranges its contents one after another along a given axis like `.x`, `.y`, or `.z`. It avoids overlap by using bounding boxes, and positions items relative to the origin using alignment on the *non-stacking* axes.

### Basic Usage

```swift
Stack(.z, spacing: 2, alignment: .centerX) {
    Cylinder(radius: 5, height: 1)
    Box([10, 10, 3])
}
```

This stacks a cylinder and a box vertically. Each item is spaced 2 mm apart, centered in X, and Y positioning is left unchanged.

### Axis and Alignment

- `axis` determines the direction of stacking.
- `spacing` is `0` by default, meaning items touch edge-to-edge. Positive values add space between them.
- `alignment` applies only to *non-stacking axes you explicitly specify*. Unspecified axes are left unchanged and the stacking axis is ignored. You can use `.center`, `.left`, `.bottom`, etc., just like with `.aligned(at:)`.
