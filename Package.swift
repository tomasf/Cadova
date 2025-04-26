// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "Cadova",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Cadova", targets: ["Cadova"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tomasf/manifold-swift.git", branch: "dev"), //.upToNextMinor(from: "0.2.0")
        //.package(path: "../manifold-swift"),
        .package(url: "https://github.com/tomasf/ThreeMF.git", branch: "main"),
        //.package(path: "../ThreeMF"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Cadova",
            dependencies: [
                .product(name: "Manifold", package: "manifold-swift"),
                .product(name: "ThreeMF", package: "ThreeMF"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: [ .interoperabilityMode(.Cxx) ]
        ),
        .testTarget(
            name: "Tests",
            dependencies: ["Cadova"],
            resources: [.copy("golden")],
            swiftSettings: [ .interoperabilityMode(.Cxx) ]
        )
    ],
    cxxLanguageStandard: .cxx17
)
