// swift-tools-version:6.3
import Foundation
import PackageDescription

// MARK: - Binary distribution
//
// On macOS, Cadova is distributed as a prebuilt, optimized XCFramework. It removes Cadova and its
// C/C++ dependencies (Manifold, oneTBB, Clipper2, pugixml, miniz, FreeType, HarfBuzz) from the
// build entirely, and it is always an optimized release build, so models run at release speed
// even while you develop in debug. Every other platform builds from source, as before.
//
// The binary is used when Cadova is consumed as a dependency. Cadova's own checkout builds from
// source, so that its tests, its documentation and the XCFramework itself are built from the
// code in the working tree.
//
// Environment overrides:
//   CADOVA_BUILD_FROM_SOURCE=1        Always build from source.
//   CADOVA_USE_BINARY=1               Always use the binary, even in Cadova's own checkout.
//   CADOVA_LOCAL_XCFRAMEWORK=<path>   Use an XCFramework on disk instead of downloading one.
//                                     SwiftPM requires this path to be relative to this package.
//
// The two flags are off when set to 0, no, false or nothing at all, so that setting one to zero
// does the obvious thing rather than the opposite of it.
//
// To run models against a local build from packages that depend on this working copy by path, run
// Scripts/build-xcframework.sh and set useLocalXCFramework below to true. Unlike
// CADOVA_LOCAL_XCFRAMEWORK this also works in Xcode, which does not pass the environment on to
// manifests. It is a line in this file rather than, say, a file on disk, because SwiftPM caches a
// manifest's result until its contents change. This working copy has no Tests target while it is
// on, and Scripts/verify-manifest-selection.sh fails if it is committed switched on. With no
// dependencies left to pin, SwiftPM also deletes Package.resolved, so restore that from git after
// switching back off.

let useLocalXCFramework = false

// Scripts/build-xcframework.sh prints the checksum, and the xcframework workflow writes both of
// these lines when it publishes a release. Until a release records a real checksum here, the
// placeholder makes this manifest fall back to a source build rather than fail to resolve.
let binaryRelease = ""
let binaryChecksum = ""
let binaryURL = "https://github.com/tomasf/Cadova/releases/download/\(binaryRelease)/Cadova.xcframework.zip"
let hasPublishedBinary = !binaryChecksum.allSatisfy { $0 == "0" }

let environment = ProcessInfo.processInfo.environment

/// Reads one of the flags above. Only a value that means something turns it on; an empty
/// variable is treated as unset, as are the usual spellings of false.
func environmentFlag(_ name: String) -> Bool {
    guard let value = environment[name]?.lowercased() else { return false }
    return ["", "0", "no", "false"].contains(value) == false
}

/// True when this manifest belongs to a checkout that SwiftPM or Xcode made for a dependency,
/// rather than to a working copy of Cadova itself.
///
/// Both put the checkout in a directory named `checkouts`, wherever the enclosing build
/// directory happens to be, so this holds under `--scratch-path` and under Xcode's
/// `SourcePackages` too. A package registry downloads to `registry/downloads` instead.
let isDependencyCheckout: Bool = {
    let directory = Context.packageDirectory
    if directory.contains("/registry/downloads/") { return true }
    return directory.split(separator: "/").dropLast().last == "checkouts"
}()

/// An XCFramework on disk to use instead of a download: the one named by CADOVA_LOCAL_XCFRAMEWORK,
/// or else the build script's output when useLocalXCFramework is on in a working copy.
let localXCFramework: String? = {
    if let path = environment["CADOVA_LOCAL_XCFRAMEWORK"], !path.isEmpty { return path }
    guard useLocalXCFramework, !isDependencyCheckout else { return nil }
    return ".build/xcframework/Cadova.xcframework"
}()

let useBinary: Bool = {
    if environmentFlag("CADOVA_BUILD_FROM_SOURCE") { return false }
    if localXCFramework != nil { return true }
    if environmentFlag("CADOVA_USE_BINARY") {
        guard hasPublishedBinary else {
            fatalError("CADOVA_USE_BINARY is set, but no XCFramework has been published for this "
                       + "version of Cadova. Unset it, or set CADOVA_LOCAL_XCFRAMEWORK to a "
                       + "path relative to this package.")
        }
        return true
    }
    #if os(macOS)
    return isDependencyCheckout && hasPublishedBinary
    #else
    return false
    #endif
}()

// MARK: - Targets

let sourceDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/tomasf/manifold-swift.git", .upToNextMinor(from: "1.1.1")),
    .package(url: "https://github.com/tomasf/ThreeMF.git", .upToNextMinor(from: "0.3.0")),
    .package(url: "https://github.com/tomasf/Apus.git", .upToNextMinor(from: "0.1.4")),
    .package(url: "https://github.com/tomasf/Pelagos.git", .upToNextMinor(from: "0.1.4")),
    .package(url: "https://github.com/tomasf/CadovaLiveLink.git", .upToNextMinor(from: "0.2.1")),
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
]

let cadovaTarget: Target = if useBinary, let path = localXCFramework {
    .binaryTarget(name: "Cadova", path: path)
} else if useBinary {
    .binaryTarget(name: "Cadova", url: binaryURL, checksum: binaryChecksum)
} else {
    .target(
        name: "Cadova",
        dependencies: [
            .product(name: "Apus", package: "Apus"),
            .product(name: "Manifold", package: "manifold-swift"),
            .product(name: "ThreeMF", package: "ThreeMF"),
            .product(name: "Pelagos", package: "Pelagos"),
            .product(name: "CadovaLiveLinkClient", package: "CadovaLiveLink", condition: .when(platforms: [.macOS])),
        ],
        swiftSettings: [ .interoperabilityMode(.Cxx) ]
    )
}

let testTarget: Target = .testTarget(
    name: "Tests",
    dependencies: [
        "Cadova",
        .product(name: "ThreeMF", package: "ThreeMF"),
        .product(name: "CadovaLiveLinkClient", package: "CadovaLiveLink", condition: .when(platforms: [.macOS])),
    ],
    resources: [.copy("golden"), .copy("resources")],
    swiftSettings: [ .interoperabilityMode(.Cxx) ]
)

let package = Package(
    name: "Cadova",
    platforms: [.macOS(.v14)],
    products: [.library(name: "Cadova", targets: ["Cadova"])] + (useBinary ? [] : [
        // Cadova and all of its dependencies as a single static archive. This is what
        // Scripts/build-xcframework.sh packages; it is not meant to be depended on directly.
        .library(name: "CadovaStatic", type: .static, targets: ["Cadova"]),
    ]),
    dependencies: useBinary ? [] : sourceDependencies,
    targets: useBinary ? [cadovaTarget] : [cadovaTarget, testTarget],
    cxxLanguageStandard: .cxx17
)
