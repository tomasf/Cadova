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
        .package(url: "https://github.com/tomasf/Cadova.git", .upToNextMinor(from: "0.5.0")),
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

On macOS, using [Cadova Viewer](https://github.com/tomasf/CadovaViewer) is recommended for the best experience. It will automatically reload the view when the model file changes.

To speed up the setup of a new model package, you can use the [template GitHub repo](https://github.com/tomasf/cadova-model-template).
