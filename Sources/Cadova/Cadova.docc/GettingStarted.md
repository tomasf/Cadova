# Getting Started

Set up a new Swift package and create your first 3D model with Cadova.

> tl;dr: Create a new executable Swift package with Cadova as a dependency, import it, define your geometry inside `Model(...) { ... }` and run the program to generate a 3MF file.

## 1. Install Swift

If you're on macOS, the easiest path is to [install the latest version of Xcode](https://developer.apple.com/xcode/).

For Windows and Linux, install Swift directly from [swift.org](https://www.swift.org/install/). We also recommend [VS Code](https://code.visualstudio.com/) with the [Swift extension](https://marketplace.visualstudio.com/items?itemName=swiftlang.swift-vscode) for a smooth editing experience. On Linux, the Fontconfig library is required; install it with `sudo apt-get install libfontconfig1-dev`.

> Tip: To skip steps 2 and 3, start from the [model package template](https://github.com/tomasf/cadova-model-template). It's a GitHub template repo with `Package.swift` and `main.swift` already set up. Press "Use this template", clone your new repository, then open `Sources/main.swift` and continue from step 4.

## 2. Create a new Swift executable package

```sh
mkdir gizmo
cd gizmo
swift package init --type executable
```

> Note: If SPM names your project file `gizmo.swift` and tries to manually add a `main` method, rename the file `main.swift` and delete the `main` method or you'll get a bunch of errors about concurrency. 

## 3. Add Cadova as a dependency

Edit `Package.swift`:

```swift
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "gizmo",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/tomasf/Cadova.git", .upToNextMinor(from: "0.9.0")),
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

Run it in your IDE or on the command line using `swift run`. This will generate a `Models/gizmo.3mf` file, relative to your package root. In Xcode, the generated model appears right in the project navigator sidebar, making it easy to find and open. You can open the file in your slicer or viewer.

On macOS, using [Cadova Viewer](https://github.com/tomasf/CadovaViewer) is recommended for the best experience. It automatically reloads the model when the file changes on disk, and offers split views, cross-sections, and measurements for inspecting your geometry in detail.

## Organize multiple models with `Project`

As your package grows to include more than one model, wrap them in a `Project` so they share that same output directory and other settings:

```swift
import Cadova

await Project(packageRelative: "Models") {
    await Model("gizmo") {
        Box([10, 10, 5])
            .subtracting {
                Sphere(diameter: 10)
                    .translated(z: 5)
            }
    }
    await Model("knob") {
        Cylinder(diameter: 12, height: 8)
    }
}
```

You can add as many `Model` entries as you like inside the `Project`, and they'll all land in that same directory. Models in a project are also evaluated in parallel, and can share environment values and metadata. See <doc:ModelAndProject> for details.
