# Cadova
<img src="https://github.com/user-attachments/assets/99d15163-d168-419c-9fc3-406e4f657074" width="40%" align="right">

Cadova is a Swift library for creating 3D models through code, with a focus on 3D printing. It offers a programmable alternative to traditional CAD tools, combining precise geometry with the expressiveness and elegance of Swift.

Cadova models are written entirely in Swift, making them easy to version, reuse, and extend. The result is a flexible and maintainable approach to modeling, especially for those already comfortable with code.

Cadova runs on macOS, Windows, and Linux. To get started, read the [Getting Started guide](https://tomasf.github.io/Cadova/documentation/cadova/gettingstarted).

Full documentation, including [What is Cadova?](https://tomasf.github.io/Cadova/documentation/cadova/whatiscadova), is available at [cadova.org/docs](https://cadova.org/docs). See the [wiki](https://github.com/tomasf/Cadova/wiki) for related projects: the viewer app, libraries, and example models built with Cadova.

[![Swift](https://github.com/tomasf/Cadova/actions/workflows/main.yml/badge.svg)](https://github.com/tomasf/Cadova/actions/workflows/main.yml)
![Platforms](https://img.shields.io/badge/Platforms-macOS_|_Linux_|_Windows-cc9529?logo=swift&logoColor=white)

## Example
<img src="https://github.com/user-attachments/assets/c8ae2128-621a-4d26-8f9a-1c277e525633" width="23%" align="right">

```swift
await Model("Hex key holder") {
    let height = 20.0
    let spacing = 8.0
    Stack(.x, spacing: spacing) {
        for size in stride(from: 1.5, through: 5.0, by: 0.5) {
            RegularPolygon(sideCount: 6, widthAcrossFlats: size)
        }
    }.measuringBounds { holes, bounds in
        Stadium(bounds.size + spacing * 2)
            .extruded(height: height)
            .subtracting {
                holes.aligned(at: .centerX)
                    .extruded(height: height)
                    .translated(z: 2)
            }
    }
}
```
For more code examples, see [Examples](https://tomasf.github.io/Cadova/documentation/cadova/examples).

To preview your models, check out [Cadova Viewer](https://github.com/tomasf/CadovaViewer), a native macOS 3MF viewer that reloads automatically as your model regenerates.

Cadova uses [Manifold-Swift](https://github.com/tomasf/manifold-swift), [Apus](https://github.com/tomasf/Apus), [Pelagos](https://github.com/tomasf/Pelagos), [Nodal](https://github.com/tomasf/Nodal) and [ThreeMF](https://github.com/tomasf/ThreeMF).


## Versioning and Stability

Cadova is currently in pre-release, with a version number below 1.0. The API is still evolving, but stability is maintained within each minor version — so `upToNextMinor(from:)` is recommended for your dependency. You're very welcome to start using Cadova today, and feedback is appreciated!

## Prebuilt binary on macOS

On macOS, Cadova resolves to a prebuilt XCFramework instead of building from source. Nothing in your manifest changes; you depend on Cadova exactly as shown above and get the binary automatically. It removes Cadova and its nine C and C++ targets from your build, and because the binary is always an optimized release build, your models run at release speed even while you build in debug.

Measured on a boolean-heavy model, building it clean and running it once:

| | From source | From the binary |
| --- | --- | --- |
| Clean debug build, wall clock | 75 s | 35 s |
| Clean debug build, CPU time | 271 s | 27 s |
| Running the model from a debug build | 1.63 s | 0.27 s |

The CPU figure is the one to watch on a laptop or a CI runner with few cores, where wall clock follows CPU time far more closely than on a many-core machine. Heavier models gain more at run time than the 6x above. The download is about 10 MB.

Linux and Windows build from source, as before.

The XCFramework carries its own copies of Manifold, ThreeMF, Nodal, Zip, Apus and Pelagos, but keeps them private, so you can still depend on any of those packages yourself and get your own copy. The one module it shares with you is `Manifold3D`, because Cadova's own API is written in terms of it: `import Manifold3D` works without declaring `manifold-swift`, and declaring it anyway gives you two copies of the same module.

To build from source on macOS too, set `CADOVA_BUILD_FROM_SOURCE=1` in the environment when you build. Cadova's own checkout always builds from source, so working on Cadova itself needs no extra setup.

To produce the artifact yourself:

```bash
Scripts/build-xcframework.sh
Scripts/verify-xcframework.sh .build/xcframework/Cadova.xcframework
Scripts/verify-manifest-selection.sh .build/xcframework/Cadova.xcframework
```

## Contributions
Contributions are welcome! If you have ideas, suggestions, or improvements, feel free to open an issue or submit a pull request. You’re also welcome to browse the [open GitHub issues](https://github.com/tomasf/Cadova/issues) and pick one to work on — especially those marked as good first issues or help wanted.

## License
This project is licensed under the MIT license. See the LICENSE file for details.

## Manifest template
```swift
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "<#name#>",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/tomasf/Cadova.git", .upToNextMinor(from: "0.9.0")),
    ],
    targets: [
        .executableTarget(
            name: "<#name#>",
            dependencies: ["Cadova"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ]
)
```
