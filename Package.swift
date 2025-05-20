// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "Cadova",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Cadova", targets: ["Cadova"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tomasf/manifold-swift.git", branch: "dev"), //.upToNextMinor(from: "0.2.0")
        .package(url: "https://github.com/tomasf/ThreeMF.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Cadova",
            dependencies: [
                .byName(name: "CadovaCPP"),
                .product(name: "Manifold", package: "manifold-swift"),
                .product(name: "ThreeMF", package: "ThreeMF"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: [ .interoperabilityMode(.Cxx) ]
        ),
        .target(
            name: "CadovaCPP",
            dependencies: [
                .product(name: "Manifold", package: "manifold-swift"),
            ],
        ),
        .testTarget(
            name: "Tests",
            dependencies: ["Cadova"],
            resources: [.copy("golden"), .copy("resources")],
            swiftSettings: [ .interoperabilityMode(.Cxx) ]
        )
    ],
    cxxLanguageStandard: .cxx17
)
