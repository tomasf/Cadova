// swift-tools-version:6.3
import PackageDescription

// A model package for testing the web customizer (see Tests/Customizer/test_customizer.py)
let package = Package(
    name: "CustomizerFixture",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(name: "Cadova", path: "../../.."),
    ],
    targets: [
        .executableTarget(
            name: "CustomizerFixture",
            dependencies: [.product(name: "Cadova", package: "Cadova")],
            path: "Sources",
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ]
)
