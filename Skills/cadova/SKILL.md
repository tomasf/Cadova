---
name: cadova
description: Build and verify 3D models with Cadova, the Swift CAD library for 3D printing. Use when writing or changing Cadova model code (Swift files that import Cadova, packages depending on github.com/tomasf/Cadova, `Model`/`Project`, `Geometry3D`), and to check a generated .3mf visually and dimensionally with the headless `cadova-viewer` CLI.
---

# Cadova

Cadova models are Swift executables. `swift run` evaluates the geometry and writes 3MF files. You can't see the model, so after each change **render it and look**. Don't assume code that compiles produces the shape you meant.

## Project setup

- Start from the template: `gh repo create <name> --template tomasf/cadova-model-template --private --clone`, or copy its manifest. Requirements: `swift-tools-version: 6.3`, `platforms: [.macOS(.v15)]`, `.package(url: "https://github.com/tomasf/Cadova.git", from: "1.0.0")`, and `swiftSettings: [.interoperabilityMode(.Cxx)]` on **every** target that imports Cadova, including shared library targets, since it doesn't carry across module boundaries. Leaving it out is the most common build failure.
- The entry point is `Sources/main.swift` with top-level `await Model("name") { ... }`. Don't add an `@main` type.
- `swift run` writes `Models/<name>.3mf` relative to the package root. The log line `Wrote model to …` gives the exact path. If generation is slow, use `swift run -c release`.
- If the user has Cadova Viewer open on that file, it reloads as soon as you regenerate.

## Look up the API; don't guess it

After the first build, the full source and documentation are in `.build/checkouts/Cadova/` (in Xcode, it's `DerivedData/<project>/SourcePackages/checkouts/Cadova/`):

- `CadovaStyleGuide.md`: how idiomatic Cadova reads. **Read it before writing model code.**
- `Sources/Cadova/Cadova.docc/*.md`: conceptual guides. By topic: transforms and mirroring → `Transformations`; `aligned`, `Stack` → `AlignmentAndStacking`; extrude, revolve, edge profiles → `ExtrusionAndRevolution`; paths, sweeps → `CurvesAndPaths`; twist, warp, loft → `BendingAndDeforming`; split, trim → `CuttingAndSplitting`; patterns, repeats → `RepetitionAndPatterns`; anchors, tags → `AnchorsAndTags`; bounds, volume → `MeasuringGeometry`; parts, colours → `WorkingWithParts`; overhangs, tolerance, shells → `DesigningFor3DPrinting`; `@Environment`, segmentation → `EnvironmentConcepts`; full models → `Examples`.
- `Sources/Cadova/`: grep it for a method's exact signature before calling it.
- If the package depends on Helical, its source is in `.build/checkouts/Helical/Sources/Helical/`. Helical has no prose docs, so read the source.

Before the first build, or outside a package, run `git clone --depth 1 https://github.com/tomasf/Cadova` into a temporary directory instead. The same docs are online at https://cadova.org/docs.

## Facts that trip people up

- Units are millimetres. Angles are `Angle` values: write `90°`, not `90`.
- Custom shapes conform to `Geometry2D`/`Geometry3D`. Pre-1.0 code (and training data) uses `Shape2D`/`Shape3D`, which no longer exist.
- Z is up. `Box`/`Rectangle` start at the origin corner and extend in the positive direction. `Circle`/`Sphere` are centred. `Cylinder` is centred in XY and goes from z = 0 up. Position things with `.aligned(at: .centerXY, .bottom)` instead of translating by half the size.
- Builder closures (`body`, `.adding {}`, `.subtracting {}`, …) union everything they contain. `if` works inside them, so you don't need `Empty()` in an `else`.
- Booleans handle coincident faces. Make cutters exactly as large as the material they remove. Don't add the epsilon overshoot that's common in OpenSCAD.
- Model profiles in 2D (`rounded`, `offset`, booleans), then `extruded`/`revolved`. This is usually far easier than shaping 3D primitives.
- `.inPart(_:)` takes geometry out of the main shape, so later booleans don't affect it. `.highlighted()` keeps the geometry and also shows it as a translucent red "Highlighted" part, which is useful for checking where a subtracted cutter sits.
- Print clearances come from the environment: `@Environment(\.tolerance) var tolerance`, set with `.withTolerance(_:)` or in `Project { Environment { $0.tolerance = 0.2 } }`.
- Threads, screws and nuts come from the separate [Helical](https://github.com/tomasf/Helical) package. Don't model helices by hand.

## Verify with cadova-viewer (macOS)

The headless viewer ships inside Cadova Viewer 1.3.2 and later:

```sh
V="/Applications/Cadova Viewer.app/Contents/Helpers/cadova-viewer"
```

If it isn't there, tell the user it comes with [Cadova Viewer](https://github.com/tomasf/CadovaViewer) 1.3.2+. On Linux and Windows it isn't available, so rely on measuring in tests (below).

### 1. Check the numbers first

```sh
"$V" info Models/part.3mf --format text
```

This gives the bounding box, volume and surface area for the whole model and for each part, plus part names and semantics. Check the dimensions against what the user asked for. The whole-model totals include visual and context parts (`.highlighted()`, `.inBackground()`, visualizations), so use the `solid` parts' figures, or narrow with `--include-part <name>`. Volume is a good test that a feature took effect: a 5 mm hole through 4 mm should remove about π·2.5²·4 ≈ 79 mm³. A cut that removes nothing still produces a valid file. The default `--format json` is easier to parse in scripts.

### 2. Render and look at the images

```sh
"$V" render Models/part.3mf /tmp/part-iso.png --width 800 --height 800
```

Rendering takes a fraction of a second, so render several views and read the PNGs back. 800 px is enough to inspect without wasting context.

- `--view isometric|front|back|left|right|top|bottom`. Isometric looks from the front-left (−X, −Y, above). Add `--azimuth 135` for the opposite, back-right corner. `--azimuth`/`--elevation` (degrees) override either angle of the preset.
- `--projection orthographic` together with `front`/`top`/`right` gives true-proportion silhouettes for comparing against a drawing.
- `--section <axis>=<pos>` cuts the model and shows the cut faces hatched. This is the way to check holes, wall thickness and internal features. **The cut removes the side the axis points to, so pick the sign that faces the camera.** For `--view front` (camera at −Y) use `-y=10`; for `top` use `z=…`; for `right` use `x=…`; for isometric use `-x=…` or `-y=…`. A plane like `1,1,0@10,0,5` (normal@point) also works. Repeat for up to 8 cuts.
- `--include-part`/`--exclude-part <name or number>` (repeatable) show a part on its own or hide one, e.g. `--exclude-part Highlighted`.
- `--no-materials` renders plain white faces with black edges, which helps when colours hide the shape. `--edges all` shows tessellation. `--smooth-shading` hides facets.
- `--transparent --trim --trim-padding 8` produce clean images for docs or a README. `--grid` adds a reference grid.

Run `"$V" render --help` for everything else.

## Measure in tests (Cadova 1.2+)

`ModelFileGenerator.evaluate` measures geometry without writing a file. It works on every platform and can measure one component on its own, unlike `info`, which only sees the finished file. Put the checks in a test target so they keep holding as the model changes:

- Keep geometry in its own types and files, not in `main.swift`.
- Add `.testTarget(name: "<name>Tests", dependencies: ["<executable>", "Cadova"], swiftSettings: [.interoperabilityMode(.Cxx)])` and `@testable import <executable>`.

```swift
@Test func `bracket fits`() async throws {
    let (bounds, volume) = try await ModelFileGenerator.evaluate(environment: { $0.tolerance = 0.2 }) { evaluator in
        (await evaluator.bounds(of: Bracket()), await evaluator.measurements(of: Bracket()).volume)
    }
    #expect(bounds?.size.z == 30)
    #expect(abs(volume - expectedVolume) < 1)   // work out expectedVolume by hand
}
```

The evaluator also offers `components(of:)` (count disconnected pieces to catch floating bits), `surfaces(of:from:in:)` (ray-cast to check wall thickness or where a hole is), `parts(of:)`, `isEmpty(_:)` and `split(_:along:)`. Grep `GeometryEvaluator+*.swift` for the full set. Work out expected values independently of the model code, and make sure a test fails when the feature is missing.

## Suggested loop

1. Edit the code, then run `swift run`. Fix compile errors with the checkout's source open, not from memory.
2. Run `info` or the tests: are the dimensions, part count and volume plausible?
3. Render isometric, then from the opposite corner, then sections through every hole, pocket or wall that matters. Read each image.
4. If something's missing or misplaced, add `.highlighted()` to the suspect cutter, regenerate and render again. Remove it when you're done.
5. Tell the user what you checked, and attach or reference the renders.
