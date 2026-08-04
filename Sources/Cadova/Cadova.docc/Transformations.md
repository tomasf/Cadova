# Transformations

Move, turn, scale, mirror and skew geometry, and work with transforms as values you can build, combine and reuse.

## Overview

Composition tells Cadova *what* a shape is made of. Transformation tells it *where that shape sits and how it is oriented*. Between them they account for most of the code in a typical model, and the two interleave freely: you position a part, subtract something from it, then rotate the result.

Every transformation method returns a new value rather than modifying anything in place, so they chain:

```swift
Cylinder(diameter: 8, height: 30)
    .rotated(y: 90°)
    .translated(x: -15, z: 20)
```

The vocabulary is deliberately small. There are five basic operations, and each one has variants that spell out its arguments in whatever form is most convenient at the call site. Distances are in millimeters and angles are ``Angle`` values, usually written with the `°` suffix (see <doc:VectorsAndAngles>).

## The basic transformations

### Translation

`.translated(_:)` moves geometry by a distance. Give it a vector, or name only the axes you care about:

```swift
shape.translated(x: 10)
shape.translated(x: 10, z: -4)
shape.translated(Vector3D(10, 0, -4))
```

For 3D geometry there is also a form that takes a `Vector2D` for the X and Y components plus a separate Z, which is handy when a 2D position is already in hand.

### Rotation

In 2D there is only one axis to turn about, so `.rotated(_:)` takes a single angle. In 3D, `.rotated(x:y:z:)` takes Euler angles and applies them **in order: first X, then Y, then Z**. Omitted axes default to `0°`.

```swift
plate.rotated(45°)                  // 2D
bracket.rotated(x: 90°)             // 3D, one axis
bracket.rotated(x: 90°, z: 180°)    // X first, then Z
```

Euler angles are awkward when you know the direction you want rather than the angles that get you there. Three alternatives cover that case:

```swift
// A named cartesian axis and an angle
part.rotated(angle: 30°, axis: .y)

// Turn one direction into another, along the shortest path
part.rotated(from: .up, to: .forward)

// Turn about an arbitrary direction
part.rotated(angle: 30°, around: Direction3D(x: 1, y: 1))
```

`.rotated(from:to:)` defaults its `from` to `.up`, so `part.rotated(to: .right)` reads as "stand this up along X instead of Z". It is the natural way to aim a feature at a surface normal you measured (see <doc:MeasuringGeometry>).

### Scaling

`.scaled(_:)` accepts a single factor for uniform scaling, or per-axis factors:

```swift
shape.scaled(2)                     // twice as big in every direction
shape.scaled(x: 2, z: 0.5)          // stretched in X, squashed in Z
shape.scaled(Vector3D(2, 2, 0.5))
```

Scaling changes the coordinate frame rather than resizing an outline, so everything inside it, including any geometry built by later operations, is scaled with it. Two related methods often turn out to be what you actually wanted: `Sphere.ellipsoid(x:y:z:)` constructs a squashed sphere directly, and `.resized(x:y:z:)` takes the size you want rather than a factor, measuring the geometry and computing the factor for you.

### Mirroring

There is no `mirrored` method. Mirroring is `.flipped(along:)`, which negates the coordinates along the axes you name:

```swift
bracket.flipped(along: .x)
```

![Two mirror-image copies of an L-shaped bracket, the gray original on the right of the origin and the orange flipped copy on the left, with the peg on opposite sides of each upright](transformations-mirror)

The parameter is an axis *set*, so `.flipped(along: .xy)` mirrors along both at once, and `.none` mirrors along nothing. That last one looks pointless until you need handed variants of the same part, where it lets a single expression cover both:

```swift
gear.flipped(along: side == .right ? .x : .none)
```

Mirroring reverses handedness, which a rotation never does. For a chiral part like the bracket above, `.flipped(along: .x)` and `.rotated(z: 180°)` give genuinely different results. When you want mirrored copies *alongside* the original rather than instead of it, use `.symmetry(over:)` from <doc:RepetitionAndPatterns>.

### Shearing

`.sheared(_:...)` slants geometry by displacing one axis in proportion to another. In 2D you name the axis to be displaced; in 3D you name both the displaced axis and the axis that drives it:

```swift
Box([24, 24, 24])
    .sheared(.x, along: .z, angle: 25°)
```

![A gray cube beside an orange copy sheared into a leaning parallelogram, its top face displaced along X in proportion to height](transformations-shear)

The magnitude can be given as an `angle:`, which is how far the sheared face leans away from square, or as a raw `factor:`, which is the displacement per unit of the driving axis. The two axes must be different, and shear angles have to stay between `-90°` and `90°`.

## Order matters

Transformations compose, and composition is not commutative. Rotating and then moving is not the same as moving and then rotating:

```swift
// Keeps its angle, slides out along X
bar.rotated(z: 40°)
    .translated(x: 45)

// Swings around the origin like an arm
bar.translated(x: 45)
    .rotated(z: 40°)
```

![The same bar transformed two ways from a shared origin: the orange copy angled but still low on the X axis, the blue copy swung far up and around](transformations-order)

Read a chain left to right as a sequence of operations on the geometry. Each one acts in the coordinate space that the previous ones produced, so a rotation late in a chain pivots whatever is already there, including any translations that came before it.

The practical rule is to shape a part around the origin first and place it last. That keeps rotations and mirrors acting on the part's own axes, where the numbers are easy to reason about, and confines position to a single trailing `.translated(...)`.

## Choosing a different pivot

Rotation is always about the origin. When you want to spin something in place, the pivot has to move to the origin first and back afterwards. Cadova packages that for you: pass a `GeometryAlignment` as `around:` and the pivot is derived from the geometry's own bounding box.

```swift
bar.rotated(z: 35°)                   // pivots at the origin
bar.rotated(z: 35°, around: .center)  // pivots at the bar's own center
```

![Two panels showing the same bar rotated 35 degrees, the upper one pivoting at the origin marker off its end, the lower one pivoting at its own center](transformations-pivot)

Any alignment works, including combinations such as `.minX, .centerY`, so you can hinge a part about an edge or a corner. Because this measures the geometry, it belongs to `Geometry` specifically rather than to every transformable type.

To rotate about an axis that is neither the origin nor a bounding-box feature, 3D geometry takes a ``Line3D``:

```swift
flap.rotated(90°, around: Line3D(point: [0, 20, 5], direction: .positiveX))
```

## Working in a transformed frame

Sometimes the transform is not the point: you want to *do* something in a rotated or shifted frame and leave the result where it was. `.whileTransformed(_:do:)` applies a transform, runs your operations in that space, and applies the inverse to whatever comes back:

```swift
panel.whileTransformed(.rotation(z: 30°)) {
    $0.subtracting {
        Box([40, 3, 10])   // a slot cut along the rotated frame's Y axis
    }
}
```

`.whileRotated(...)` is the same thing for the common case where the transform is a pure rotation, and `.whileAligned(at:)` (see <doc:AlignmentAndStacking>) does it for alignment. All three save you from writing the transform, its inverse, and the bookkeeping in between.

## The same vocabulary beyond geometry

`.translated`, `.rotated`, `.scaled` and the rest are not methods on geometry. They come from the ``Transformable`` protocol, which anything positioned in space can adopt, so the same calls work on the values you build geometry *from*:

```swift
let outline = BezierPath2D {
    line(x: 10)
    line(y: 6)
}
.rotated(90°)
.translated(x: 5)
```

Besides ``Geometry``, this covers ``BezierPath``, ``SplineCurve``, ``InterpolatingCurve`` and ``BezierPatch``. Transforming a curve before turning it into geometry is often cheaper and clearer than transforming the geometry afterwards.

A couple of neighboring types work similarly without being `Transformable`. ``Plane`` has its own `translated(...)` and `rotated(...)`, which carry both its position and its normal. Single points are transformed with `transform.apply(to: point)`.

## Transforms as values

Everything above is built on ``Transform2D`` and ``Transform3D``, affine matrices you can construct and pass around directly. Start one with a static factory such as `.translation(...)`, `.rotation(...)`, `.scaling(...)` or `.shearing(...)`, and build it up from there with the very same methods you use on geometry, because transforms are ``Transformable`` too:

```swift
let placement = Transform3D.translation(x: 10, z: 4)
    .rotated(z: 45°)

part.transformed(placement)
```

A transform chain reads exactly like a geometry chain, left to right in the order the operations happen. `placement` translates first and then rotates, so it is a different transform from `Transform3D.rotation(z: 45°).translated(x: 10, z: 4)`, which rotates first. It is the same trap as <doc:Transformations#Order-matters>, one level down.

To combine two transforms you already have, `concatenated(with:)` composes them in that same order, and `*` is its operator spelling. Other useful members:

- `.identity`, the transform that changes nothing, and `isIdentity` to test for it
- `.inverse`, for undoing a transform
- `.apply(to:)`, which transforms a single point rather than geometry
- `.offset` and `.scale`, the translation and per-axis scale factors the transform encodes
- `Transform3D.linearInterpolation(_:_:factor:)`, for blending between two transforms

For building a local coordinate frame from scratch, `Transform3D(orthonormalBasisOrigin:x:y:z:)` takes an origin and three ``Direction3D`` basis vectors.

Transform values are what several APIs accept in place of a plain position. `.extruded(along:)` takes an array of them to sweep a profile through a sequence of placements, and `.distributed(at:)` (see <doc:RepetitionAndPatterns>) takes them to scatter copies at arbitrary orientations rather than along a single axis.

## Transforms and the environment

Cadova records the accumulated transform in the environment as geometry is built, so a shape can find out how it has been placed by everything above it. Two things depend on this.

The first is direction. `naturalUpDirection` and the overhang helpers that read it (see <doc:DesigningFor3DPrinting>) need to know which way is up *after* all the rotations that will be applied to a part, and the recorded transform is how they find out.

The second is scale. Because adaptive segmentation is expressed in millimeters, geometry built inside a `.scaled(...)` would otherwise come out coarser or finer than intended once the scaling is applied. Cadova compensates: the environment exposes a `scale` factor derived from the current transform, and both segmentation and tolerance are adjusted by it so that detail and fit stay consistent no matter what frame a part is built in.

## Beyond affine transforms

Everything on this page is *affine*: straight lines stay straight and parallel lines stay parallel. Operations that break that rule work differently, moving individual vertices rather than the frame as a whole, and only affect points that already exist in the mesh, so they usually want a `.refined(maxEdgeLength:)` beforehand.

That family includes `.twisted(by:)`, `.wrappedAroundCylinder(diameter:)` and its circle and sphere counterparts, `.deformed(by:)` for following a curve or a ``BezierPatch``, `.skewingCorners(_:)` for dragging the corners of a bounding box, and the general-purpose `.warped(...)`, which `scaled(along:operationName:scale:)` is built on. See <doc:BendingAndDeforming>.

## Related Reading

- <doc:VectorsAndAngles> for the vector and angle types the transformations take
- <doc:AlignmentAndStacking> for positioning by bounding box rather than by distance
- <doc:RepetitionAndPatterns> for producing many placed copies at once
- <doc:AnchorsAndTags> for placing geometry relative to a frame defined somewhere else
