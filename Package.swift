// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Cadova",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Cadova", targets: ["Cadova"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tomasf/manifold-swift.git", .upToNextMinor(from: "0.4.0")),
        .package(url: "https://github.com/tomasf/ThreeMF.git", .upToNextMinor(from: "0.2.0")),
        .package(url: "https://github.com/tomasf/Apus.git", .upToNextMinor(from: "0.1.1")),
        .package(path: "../Pelagos"),
    ],
    targets: [
        .target(
            name: "Cadova",
            dependencies: [
                .byName(name: "CadovaCPP"),
                .product(name: "Apus", package: "Apus"),
                .product(name: "Manifold", package: "manifold-swift"),
                .product(name: "ThreeMF", package: "ThreeMF"),
                .product(name: "Pelagos", package: "Pelagos")
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
