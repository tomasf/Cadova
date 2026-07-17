# Getting Started

Set up a new Swift package and create your first 3D model with Cadova.

> tl;dr: Create a new executable Swift package with Cadova as a dependency, import it, define your geometry inside `Model(...) { ... }` and run the program to generate a 3MF file.

## 1. Install Swift

If you're on macOS, the easiest path is to [install the latest version of Xcode](https://developer.apple.com/xcode/).

For Windows and Linux, install Swift directly from [swift.org](https://www.swift.org/install/). We also recommend [VS Code](https://code.visualstudio.com/) with the [Swift extension](https://marketplace.visualstudio.com/items?itemName=swiftlang.swift-vscode) for a smooth editing experience. On Linux, the Fontconfig library is required; install it with `sudo apt-get install libfontconfig1-dev`.

## 2. Create a new Swift executable package

```sh
mkdir gizmo
cd gizmo
swift package init --type executable
```

## 3. Add Cadova as a dependency

Edit `Package.swift`:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "gizmo",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/tomasf/Cadova.git", .upToNextMinor(from: "0.8.0")),
    ],
    targets: [
        .executableTarget(
            name: "gizmo",
            dependencies: ["Cadova"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        )
    ]
)
```

## 4. Use Cadova

Edit `main.swift`:

![A box with a sphere subtracted from it](getting-started-example)

```swift
import Cadova

await Model("gizmo") {
    Box([10, 10, 5])
        .subtracting {
            Sphere(diameter: 10)
                .translated(z: 5)
        }
}
```

Run it in your IDE or on the command line using `swift run`. This will generate a `gizmo.3mf` file in the current directory. You can open it in your slicer or viewer.

On macOS, using [Cadova Viewer](https://github.com/tomasf/CadovaViewer) is recommended for the best experience. It automatically reloads the model when the file changes on disk, and offers split views, cross-sections, and measurements for inspecting your geometry in detail.

To speed up the setup of a new model package, you can use the [template GitHub repo](https://github.com/tomasf/cadova-model-template).

## Organize your output with `Project`

As your package grows to include more than one model, it's nice to keep generated files together. ``Project`` groups multiple models under a shared output directory, and `packageRelative` points that directory at a path relative to your package root. This also means files show up in a predictable location within your package folder. In Xcode, the generated models appear right in the project navigator sidebar, making them easy to find and open.

```swift
import Cadova

await Project(packageRelative: "Models") {
    await Model("knob") {
        Cylinder(diameter: 12, height: 8)
    }
}
```

This saves output to `Models/knob.3mf` inside your package. You can add as many `Model` entries as you like inside the `Project`, and they'll all land in that same directory.
