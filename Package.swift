// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "SwiftSCAD",
    products: [
        .library(
            name: "SwiftSCAD",
            targets: ["SwiftSCAD"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftSCAD",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "Tests",
            dependencies: ["SwiftSCAD"],
            resources: [.copy("SCAD")]
        )
    ]
)
