# Model and Project

Export your geometry as 3MF files using Model, and use Project to control where that output goes and to group multiple models together.

## Overview

For simple cases, use `Model("filename") { ... }`:

```swift
await Model("pie") {
    Circle(diameter: 5)
        .subtracting {
            Rectangle(5)
                .aligned(at: .top, .right)
        }
}
```

This writes a 2D or 3D model to disk. The string `pie` is used to name the model file: If the name is a simple string (no path), the file is written to the current working directory. If it's a full path or URL, the model is saved there.

## Using Projects

Even for a single model, it's usually worth wrapping it in a `Project` using `packageRelative`:

```swift
await Project(packageRelative: "Models") {
    await Model("pie") {
        Circle(diameter: 5)
            .subtracting {
                Rectangle(5)
                    .aligned(at: .top, .right)
            }
    }
}
```

This saves output to `Models/pie.3mf`, relative to your package root — regardless of the current working directory the program happens to be run from (Xcode and the terminal often differ here). In Xcode, files placed this way also show up directly in the project navigator, making them easy to find and open. Plain `Model("pie") { ... }` writes to the current working directory instead, which is fine for a quick one-off test but not something to rely on otherwise.

Once a project holds more than one model, you get further benefits:

- Models are evaluated in parallel, speeding up builds.
- You can apply default *environment values* to all models by using Environment directives in the project builder.
- Metadata can be shared across models and merged/overridden per model.

```swift
await Project(root: "~/Desktop/Garden Tools") {
    Metadata(
        title: "Garden Tools",
        author: "Tomas F"
    )
    Environment {
        $0.tolerance = 0.2
    }

    await Model("spade") { ... }
    await Model("flashlight") { ... }
}
```

## Model Options

Both ``Model`` and `Project` accept options to customize output:

### Format

Choose the output file format:

- 2D: `.svg` or `.threeMF`
- 3D: `.stl` or `.threeMF`

`.threeMF` is the default and preferred format due to its versatility. It supports materials and part metadata, stores multiple parts in one file and enables better integration with slicers and 3D printing tools. STL is supported for broader compatibility but lacks these features.

```swift
await Model("spade", options: .format3D(.stl)) { ... }
```

### Metadata

Metadata can be provided directly as ModelOptions, but also through `Metadata(...)` directives in the result builder:

```swift
await Model("spade") {
    Metadata(title: "Spade", description: "A nice spade for garden work")
    ...
}
```

### Compression

Control compression level for 3MF files. Higher compression reduces file size but increases export time.

```swift
await Model("spade", options: .compression(.smallest)) { ... }
```

## When a Model Fails

A model can fail to build — geometry that can't be evaluated, an import that isn't there, a builder
that produces no geometry at all — or fail to be written, because the destination directory is
read-only or the disk is full.

Within a `Project`, one failure never stops the rest of the build. Every model that can be built
still is, each failure is logged, and then the program ends once, with a **non-zero exit status**.
That last part is what lets a shell, a Makefile or a CI job tell a failed build from a successful
one:

```sh
swift run && open Models/knob.3mf
```

Two limits on that are worth knowing, because both follow from where the process ends. A standalone
`Model` is its own top-level build, so it ends the program as soon as it fails: a script listing
several bare models stops at the first one that fails, and wrapping them in a `Project` is what
builds them all. And a `Group` whose directory cannot be created skips the models inside it, since
there is nowhere left to write them.

`Project` also returns a ``BuildOutcome`` describing what happened, which you can inspect instead of
letting the failure end the process:

```swift
let outcome = await BuildFailureBehavior.report.whileCurrent {
    await Project(packageRelative: "Models") {
        await Model("knob") { Knob() }
    }
}

for failure in outcome.failures {
    print(failure)          // "Failed to write model "knob" to …: …"
}
```

``BuildFailureBehavior/report`` is what you want if Cadova is embedded in a program that has to stay
alive, and it's also what a test that deliberately builds a broken model needs, since the default
behavior would end the test process. A standalone `Model` has no return value to carry an outcome,
so under `.report` its failures are only logged.

## Programmatic API

For GUI applications, servers, or other contexts where you need control over where and how files are saved, use ``ModelFileGenerator`` instead of ``Model``.

```swift
let modelFile = try await ModelFileGenerator.build(named: "my-model") {
    Box(x: 10, y: 10, z: 5)
}

let data = try await modelFile.data()           // Access raw bytes in memory
try await modelFile.write(to: customURL)        // Write to a specific location
let fileName = modelFile.suggestedFileName      // e.g., "my-model.3mf"
```

If you're building multiple models, create a ``ModelFileGenerator`` instance to benefit from caching:

```swift
let generator = ModelFileGenerator()

let part1 = try await generator.build(named: "model1") { ... }
let part2 = try await generator.build(named: "model2") { ... }
```

``ModelFileGenerator`` accepts the same options and directives as ``Model``, including `Metadata` and `Environment`.

## Cadova Viewer

[Cadova Viewer](https://github.com/tomasf/CadovaViewer) is a macOS-native application designed to preview models created in Cadova. It watches your files and reloads automatically as they are regenerated. This makes it ideal for iterative modeling.
