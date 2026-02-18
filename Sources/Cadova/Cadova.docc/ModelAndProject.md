# Model and Project

Export your geometry as 3MF files using Model and organize multiple outputs with Project.

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

For multiple model files, wrap them in a `Project`:

```swift
await Project {
    await Model("pie") {
        Circle(diameter: 5)
            .subtracting {
                Rectangle(5).aligned(at: .top, .right)
            }
    }

    await Model("squished") {
        Sphere(diameter: 10)
            .scaled(z: 0.6)
    }
}
```

This offers several benefits:

- Models are evaluated in parallel, speeding up builds.
- You can set a common *root directory* for the models.
- You can apply default *environment values* to all models by using Environment directives in the project builder.

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
