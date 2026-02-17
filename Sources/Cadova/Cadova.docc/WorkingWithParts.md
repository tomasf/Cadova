# Working with Parts

Split a model into named parts for separate viewing and print settings.

## Overview

Cadova supports splitting a model into *named parts*, which appear as separate objects in the exported 3MF file. This is useful in several contexts:

- In *Cadova Viewer*, individual parts can be shown or hidden for focused inspection.
- In slicers like *PrusaSlicer* or *Bambu Studio*, different print settings (such as infill, speed, or supports) can be applied to each part independently.

## Defining Parts

Parts are defined using the ``Part`` type:

```swift
let base = Part("Base")
let cover = Part("Cover", color: .blue)
```

Each ``Part`` instance has a unique identity. Parts are grouped by instance, not by name; two ``Part`` values with the same name are still distinct parts if created separately.

## Using `.inPart(_:)`

To assign geometry to a part, apply `.inPart(_:)`:

```swift
let base = Part("Base")

Box(x: 20, y: 20, z: 5)
    .inPart(base)
```

This registers the geometry as a **separate part** in the output model.

You can use the **same `Part` instance** multiple times to group multiple shapes into a single part:

```swift
let base = Part("Base")

Box(x: 20, y: 20, z: 5)
    .inPart(base)

Cylinder(diameter: 10, height: 10)
    .translated(x: 10, y: 10)
    .inPart(base)
```

In this example, both the box and the cylinder will be included in a single part named `Base`.

## How It Works

Calling `.inPart(_:)` **detaches the geometry from the main model**. It does not return the original shape. Instead, it returns an *empty geometry placeholder*. This means:

- The part will *not participate in subsequent modeling operations*
- You *cannot union, subtract, or modify* the part further after applying `.inPart(_:)`
- The geometry is extracted and stored in an out-of-band registry of parts

This behavior is by design, ensuring that parts remain isolated and well-defined in the output. Note that using measurement methods *will* include separated parts by default. There are also a number of methods to work with parts, for operations such as modification and removal.

## Transform Propagation

Although parts are detached from the main geometry tree, they do *follow transformations* applied after `.inPart(_:)`:

```swift
let cover = Part("Cover")

Box(x: 20, y: 20, z: 5)
    .inPart(cover)
    .translated(x: 10)
```

In this example:
- The box will be included in a part named `Cover`
- The part will be placed at `x = 10` in the final model

Transforms are preserved. Further modeling operations are not applied.
