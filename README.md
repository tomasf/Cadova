# Cadova
<img src="https://github.com/user-attachments/assets/99d15163-d168-419c-9fc3-406e4f657074" width="40%" align="right">

Cadova is a Swift library for creating 3D models through code, with a focus on 3D printing. It offers a programmable alternative to traditional CAD tools, combining precise geometry with the expressiveness and elegance of Swift.

Cadova models are written entirely in Swift, making them easy to version, reuse, and extend. The result is a flexible and maintainable approach to modeling, especially for those already comfortable with code.

Cadova runs on macOS, Windows, and Linux. To get started, read the [Getting Started guide](https://github.com/tomasf/Cadova/wiki/Getting-Started).

More documentation is available in the [Wiki](https://github.com/tomasf/Cadova/wiki). Read [What is Cadova?](https://github.com/tomasf/Cadova/wiki/What-is-Cadova%3F) for an introduction. For code examples, see [Examples](https://github.com/tomasf/Cadova/wiki/Examples).

[![Swift](https://github.com/tomasf/Cadova/actions/workflows/main.yml/badge.svg)](https://github.com/tomasf/Cadova/actions/workflows/main.yml)
![Platforms](https://img.shields.io/badge/Platforms-macOS_|_Linux_|_Windows-cc9529?logo=swift&logoColor=white)

## Related Projects
* [Cadova Viewer](https://github.com/tomasf/CadovaViewer) - A native macOS 3MF viewer application
* [Helical](https://github.com/tomasf/Helical) - A Cadova library providing customizable threads, screws, bolts, nuts and related parts.

Cadova uses [Manifold-Swift](https://github.com/tomasf/manifold-swift), [ThreeMF](https://github.com/tomasf/ThreeMF),
[freetype-spm](https://github.com/tomasf/freetype-spm) and [FindFont](https://github.com/tomasf/FindFont).


## Versioning and Stability

Cadova is currently in pre-release, with a version number below 1.0. The API is still evolving, but stability is maintained within each minor version — so `upToNextMinor(from:)` is recommended for your dependency. You're very welcome to start using Cadova today, and feedback is appreciated!

## Contributions
Contributions are welcome! If you have ideas, suggestions, or improvements, feel free to open an issue or submit a pull request. You’re also welcome to browse the [open GitHub issues](https://github.com/tomasf/Cadova/issues) and pick one to work on — especially those marked as good first issues or help wanted.

## License
This project is licensed under the MIT license. See the LICENSE file for details.

## Manifest template
```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "<#name#>",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/tomasf/Cadova.git", .upToNextMinor(from: "0.4.0")),
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
