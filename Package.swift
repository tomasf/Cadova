// swift-tools-version:6.3
import PackageDescription

let package = Package(
    name: "Cadova",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Cadova", targets: ["Cadova"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tomasf/manifold-swift.git", .upToNextMinor(from: "1.1.1")),
        .package(url: "https://github.com/tomasf/ThreeMF.git", .upToNextMinor(from: "0.2.4")),
        .package(url: "https://github.com/tomasf/Apus.git", .upToNextMinor(from: "0.1.4")),
        .package(url: "https://github.com/tomasf/Pelagos.git", .upToNextMinor(from: "0.1.4")),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "Cadova",
            dependencies: [
                .product(name: "Apus", package: "Apus"),
                .product(name: "Manifold", package: "manifold-swift"),
                .product(name: "ThreeMF", package: "ThreeMF"),
                .product(name: "Pelagos", package: "Pelagos"),
                "LiveLink"
            ],
            swiftSettings: [ .interoperabilityMode(.Cxx) ]
        ),
        .target(name: "LiveLink"),
        .testTarget(
            name: "Tests",
            dependencies: [
                "Cadova", "LiveLink",
                .product(name: "ThreeMF", package: "ThreeMF")
            ],
            resources: [.copy("golden"), .copy("resources")],
            swiftSettings: [ .interoperabilityMode(.Cxx) ]
        )
    ],
    cxxLanguageStandard: .cxx17
)
