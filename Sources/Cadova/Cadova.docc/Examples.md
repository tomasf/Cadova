# Examples

Example models showing how Cadova's features come together in practical, printable parts.

## Filleted bracket

![An L-shaped bracket with a gusset, slots and filleted edges](example-bracket)

The L profile is drawn in 2D, where `rounded(insideRadius:)` gives it a strong inside corner, then extruded across the width. Since the bracket prints lying on its base, the horizontal holes use `overhangSafe(.teardrop)`. Finally, `shapingEdges(_:matching:)` rounds every convex edge of the finished part, including the hole and slot rims.

```swift
let legLength = 36.0
let thickness = 5.0
let gussetInset = 6.0
let screwHoleDiameter = 5.5
let holeOffset = 13.0

// The L profile, with a generous inside fillet, extruded across the width
Rectangle(x: legLength, y: thickness)
    .adding { Rectangle(x: thickness, y: legLength) }
    .rounded(insideRadius: 6)
    .extruded(height: 46)
    .aligned(at: .centerZ)
    .adding {
        // Gusset between the base and the upright
        Polygon([
            [thickness, thickness],
            [legLength - gussetInset, thickness],
            [thickness, legLength - gussetInset]
        ])
        .extruded(height: thickness)
        .aligned(at: .centerZ)
    }
    .rotated(x: 90°)
    .subtracting {
        // Slots in the base for adjustment
        Circle(diameter: screwHoleDiameter)
            .clonedAt(x: 10)
            .convexHull()
            .translated(x: 15, y: holeOffset)
            .symmetry(over: .y)
            .extruded(height: thickness)

        // Holes in the upright, teardrop-shaped so they print cleanly
        Cylinder(diameter: screwHoleDiameter, height: thickness)
            .overhangSafe(.teardrop)
            .rotated(y: 90°)
            .translated(y: holeOffset, z: 24)
            .symmetry(over: .y)
    }
    .shapingEdges(.fillet(radius: 1), matching: .convex)
    .withMaterial(.glossyPlastic(.royalBlue))
```

## Wall hook

![A wall hook with a swept arm and countersunk screw holes](example-hook)

The arm is a circle swept along a 3D Bézier path, ending in a ball. The plate is a rounded rectangle with countersunk screw holes, placed so the arm leaves a clear path for a screwdriver, and a flared cone at the arm's root makes the joint stronger.

```swift
let plateHeight = 80.0
let plateThickness = 5.0
let countersinkDiameter = 9.0
let screwInset = 10.0
let armDiameter = 10.0

// Where the arm leaves the plate, the bottom of its bend, and its ball tip
let armRoot = Vector3D(0, 0, 44)
let armBend = Vector3D(0, 30, 32)
let ballCenter = Vector3D(0, 46, 34)
let arm = BezierPath3D(startPoint: armRoot)
    .addingCurve(armRoot + [0, 20, 0], armBend + [0, 0, 8], armBend)
    .addingCurve(armBend - [0, 0, 10], ballCenter - [0, 2, 12], ballCenter)

// The plate is drawn flat, front face down, then stood up against the wall
Rectangle(x: 28, y: plateHeight)
    .aligned(at: .centerX)
    .rounded(radius: 8)
    .extruded(height: plateThickness, bottomEdge: .fillet(radius: 1.5))
    .subtracting {
        // Countersunk screw holes: a 90° cone on top of a plain hole
        Cylinder(diameter: 4.5, height: plateThickness)
            .adding {
                Cylinder(
                    bottomDiameter: countersinkDiameter,
                    topDiameter: 0,
                    height: countersinkDiameter / 2
                )
            }
            .distributed(at: [screwInset, plateHeight - screwInset], along: .y)
    }
    .rotated(x: 90°)
    .adding {
        // The arm, placed so a screwdriver has a clear path to both screws
        Circle(diameter: armDiameter)
            .swept(along: arm, pointing: .up, toward: .direction(.positiveX))
        Sphere(diameter: 13)
            .translated(ballCenter)

        // A flared root where the arm meets the plate
        Cylinder(bottomDiameter: 18, topDiameter: armDiameter, height: 8)
            .rotated(x: -90°)
            .translated(armRoot)
    }
    .withMaterial(.glossyPlastic(.gold))
```

## Lofted vase

![A vase lofted from a circle through twisted flower-shaped sections](example-vase)

`Loft` blends between 2D sections at different heights, even when they have different shapes. Insetting the whole solid with a 3D `offset(amount:style:)` and subtracting it hollows the vase while keeping a floor, and `within(z:)` trims off the closed top.

```swift
let height = 160.0
let flowerDiameter = 64.0
let petalCount = 8

// A scalloped flower outline
let flower = Circle(diameter: flowerDiameter)
    .adding {
        Circle(diameter: 20)
            .translated(x: flowerDiameter / 2)
            .repeated(count: petalCount)
    }
    .rounded(insideRadius: 8)

// The top section reaches past the rim, to be trimmed off later
let vase = Loft(interpolation: .smootherstep) {
    Section(at: 0) { Circle(diameter: 54) }
    Section(at: 60) { flower.rotated(180° / Double(petalCount)) }
    Section(at: 130) { flower.scaled(0.55) }
    Section(at: height + 10) { Circle(diameter: 42) }
}

// An inward 3D offset leaves a floor and a closed top of the same thickness,
// and trimming to the final height opens the top
vase.subtracting { vase.offset(amount: -1.6) }
    .within(z: ...height)
    .withMaterial(.glossyPlastic(.teal))
```

## Knurled knob

![A knurled control knob with a D-shaped shaft hole](example-knob)

A diamond knurl comes from extruding the same grooved circle with opposite twists and intersecting the two. The dished top, pointer line and D-shaft hole are plain boolean subtractions.

```swift
let diameter = 30.0
let height = 16.0
let knurlTwist = 60°

// Diamond knurl: one grooved circle, twisted both ways and intersected
let grooved = Circle(diameter: diameter)
    .subtracting {
        Rectangle(1.6)
            .aligned(at: .center)
            .rotated(45°)
            .translated(x: diameter / 2)
            .repeated(count: 30)
    }

grooved.extruded(height: height, twist: knurlTwist)
    .intersecting {
        grooved.extruded(height: height, twist: -knurlTwist)
        Circle(diameter: diameter)
            .extruded(height: height, topEdge: .chamfer(depth: 1.5))
    }
    .adding {
        // Skirt
        Circle(diameter: diameter + 8)
            .extruded(height: 3, topEdge: .fillet(radius: 1))
    }
    .subtracting {
        // Dished top with a pointer line
        Sphere(diameter: 60)
            .aligned(at: .minZ)
            .translated(z: height - 1)
        Box(x: 2, y: diameter / 2 - 4, z: 1.5)
            .aligned(at: .centerX, .maxZ)
            .translated(z: height)

        // D-shaft hole
        Circle(diameter: 6.2)
            .within(y: ...1.6)
            .extruded(height: 12)
    }
    .withMaterial(.anodizedAluminium(Color(0.22, 0.24, 0.28)))
```

## Name tag

![A name tag with raised white letters on a dark base](example-name-tag)

Aligning the text at its left edge gives the key ring tab a fixed place, and offsetting the text outline makes a tag that fits any name. Giving the letters their own material puts them in a separate object in the 3MF file, ready for a filament change or a multi-material printer.

```swift
// The text starts just right of the key ring tab, which sits at the origin,
// so the tag fits whatever the name is
let text = Text("Cadova")
    .withFont("Avenir Next", style: "Heavy", size: 16)
    .aligned(at: .minX, .centerY)
    .translated(x: 6)

Stack(.z) {
    text.offset(amount: 3.5, style: .round)
        .adding { Circle(diameter: 16) }
        .rounded(insideRadius: 3)
        .subtracting { Circle(diameter: 6) }
        .extruded(height: 3, topEdge: .chamfer(depth: 0.6))
        .withMaterial(.glossyPlastic(Color(0.1, 0.12, 0.22)))

    // Raised letters in a second color, for multi-material printing
    text.extruded(height: 1)
        .withMaterial(.glossyPlastic(.white))
}
```

## Bit holder

![A stepped holder for screwdriver bits, with bits in place](example-bit-holder)

The socket positions are plain Swift values, computed once and used both for the holes, through `distributed(at:)`, and for the bits. The bits are part of the model so you can check the fit, but they go in a part with `.visual` semantics, which viewers show and slicers leave out.

```swift
let columnCount = 6
let pitch = 11.0
let rowHeights = [10.0, 17.0, 24.0]
let socketDepth = 10.0

// 1/4" hex, the standard screwdriver bit shank
let hexWidth = 6.35

// The bottom center of every socket, one row per step
let sockets = rowHeights.enumerated().flatMap { row, rowHeight in
    (0..<columnCount).map { column in
        Vector3D(
            pitch * (Double(column) + 0.5),
            pitch * (Double(row) + 0.5),
            rowHeight - socketDepth
        )
    }
}

// Stepped rows, each one taller than the one in front of it
Stack(.y) {
    for rowHeight in rowHeights {
        Box(x: Double(columnCount) * pitch, y: pitch, z: rowHeight)
    }
}
.subtracting {
    RegularPolygon(sideCount: 6, widthAcrossFlats: hexWidth + 0.2)
        .extruded(height: socketDepth)
        .distributed(at: sockets)
}
.shapingEdges(.fillet(radius: 1.2), matching: .convex)
.withMaterial(.mattePlastic(Color(0.22, 0.24, 0.27)))

// A Phillips bit: a hex shank with a detent groove, then a cone with four
// tapered wings running up it and sloped flutes between them
let tipLength = 8.0
let cornerDiameter = hexWidth / cos(30°)
let bit = Stack(.z) {
    RegularPolygon(sideCount: 6, widthAcrossFlats: hexWidth)
        .extruded(height: 17)
        .subtracting {
            Ring(outerDiameter: cornerDiameter, innerDiameter: 5.2)
                .extruded(height: 1.4)
                .translated(z: 12)
        }

    Cylinder(bottomDiameter: cornerDiameter, topDiameter: 0.8, height: tipLength)
        .intersecting {
            Rectangle(x: cornerDiameter, y: 2.4)
                .aligned(at: .center)
                .extruded(height: tipLength, topScale: [1, 0.3])
                .cloned { $0.rotated(z: 90°) }
                .adding {
                    Cylinder(bottomDiameter: 5.6, topDiameter: 0, height: 7)
                }
        }
}

// Bits are shown in the model, but in a visual part so they don't print
let bits = Part("Bits", semantic: .visual, material: Material(
    name: "Clear Steel",
    baseColor: Color(0.8, 0.82, 0.85, 0.8),
    metallicness: 1,
    roughness: 0.25
))

for (index, socket) in sockets.enumerated() where ![3, 8, 13].contains(index) {
    bit.translated(socket)
        .inPart(bits)
}
```
