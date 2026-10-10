import Foundation

/// The swift.org toolchain, Swift WebAssembly SDK and Binaryen a customizer is built with.
///
/// The plugin keeps its own copy of the SDK in its work directory and patches it, so the patches
/// never touch an SDK installed for other projects.
struct WebAssemblyToolchain {
    static let swiftVersion = "6.4.0"
    static let sdkName = "swift-\(swiftVersion)-RELEASE_wasm"
    static let sdkURL = URL(string: "https://download.swift.org/swift-\(swiftVersion)-release/wasm-sdk/swift-\(swiftVersion)-RELEASE/\(sdkName).artifactbundle.tar.gz")!
    static let sdkChecksum = "f07b7be3c586d92d7a07051fc6d303b87ebea67eadc40640ba59d5a8b79aa86d"

    static let binaryenVersion = "133"
    static let binaryenChecksums = [
        "arm64-macos": "ad66da82ac13f163e424b1643f16c6dfcccc98b5966296b43e52d3cab04f84a8",
        "x86_64-macos": "13a9b90be775c6389ce3d1f879cb8627bea56708ba8c122983941d53a8199b95",
        "x86_64-linux": "2dc9c7813f5375db93d96ead4b78222fcc3e2677bbb832297af4797782a37489",
        "aarch64-linux": "89c07ea56faf38d0fbecf36ca8ec0721756716185f265b568e133d427f299bf8",
    ]

    /// The toolchain's `usr/bin`
    let binaries: URL
    let sdksDirectory: URL
    let wasmOpt: URL

    var sdkRoot: URL { sdksDirectory.appending(path: "\(Self.sdkName).artifactbundle/\(Self.sdkName)/wasm32-unknown-wasip1") }
    var sysroot: URL { sdkRoot.appending(path: "WASI.sdk") }
    var swiftResources: URL { sdkRoot.appending(path: "swift.xctoolchain/usr/lib/swift_static") }
    var sdkLibraries: URL { swiftResources.appending(path: "wasi") }
    var sharedSDKLibraries: URL { sdkRoot.appending(path: "swift.xctoolchain/usr/lib/swift/wasi") }

    /// Finds the toolchain, and downloads and patches the SDK and Binaryen if they're not in the
    /// work directory yet.
    static func prepare(in workDirectory: URL, support: URL) throws -> Self {
        let toolchain = Self(
            binaries: try locateToolchain(),
            sdksDirectory: workDirectory.appending(path: "swift-sdks"),
            wasmOpt: workDirectory.appending(path: "binaryen-version_\(binaryenVersion)/bin/wasm-opt")
        )
        try toolchain.installSDK()
        try toolchain.installBinaryen(in: workDirectory)
        try toolchain.patchModuleMap()
        try toolchain.installCxxRuntime(support: support)
        try toolchain.leaveOutICUData(support: support)
        return toolchain
    }

    private static func locateToolchain() throws -> URL {
        let fileManager = FileManager.default
        let isToolchain = { (directory: URL) in
            fileManager.isExecutableFile(atPath: directory.appending(path: "usr/bin/swift").path)
        }

        // A location given explicitly has to be right, rather than quietly falling back to others
        if let path = ProcessInfo.processInfo.environment["CADOVA_WASM_TOOLCHAIN"] {
            let directory = URL(fileURLWithPath: path)
            guard isToolchain(directory) else {
                throw CustomizerError("""
                    CADOVA_WASM_TOOLCHAIN is set to \(path), but there's no usr/bin/swift there. Set it \
                    to the directory of the Swift \(swiftVersion) toolchain from swift.org, the one that \
                    contains usr/bin.
                    """)
            }
            return directory.appending(path: "usr/bin")
        }

        let candidates = standardToolchainLocations
        if let directory = candidates.first(where: isToolchain) {
            return directory.appending(path: "usr/bin")
        }

        let home = fileManager.homeDirectoryForCurrentUser.path
        let lookedIn = candidates.map { "  " + $0.path.replacingOccurrences(of: home, with: "~") }.joined(separator: "\n")
        #if os(macOS)
        let package = "  https://download.swift.org/swift-\(swiftVersion)-release/xcode/swift-\(swiftVersion)-RELEASE/swift-\(swiftVersion)-RELEASE-osx.pkg"
        #else
        let package = "  the toolchain for your distribution from https://www.swift.org/install"
        #endif
        throw CustomizerError("""
            Building for WebAssembly needs the Swift \(swiftVersion) toolchain from swift.org. Xcode's \
            Swift can't be used, even when it's the same version.

            Install it with one of:
              swiftly install \(swiftVersion)    (swiftly: https://www.swift.org/install; run \
            `swiftly self-update` first if it can't find \(swiftVersion))
            \(package)

            Looked in:
            \(lookedIn)

            If it's installed somewhere else, set CADOVA_WASM_TOOLCHAIN to its directory.
            """)
    }

    /// Where swift.org's installer and swiftly put the toolchain
    private static var standardToolchainLocations: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        #if os(macOS)
        let bundle = "swift-\(swiftVersion)-RELEASE.xctoolchain"
        return [
            home.appending(path: "Library/Developer/Toolchains/\(bundle)"),
            URL(fileURLWithPath: "/Library/Developer/Toolchains/\(bundle)"),
        ]
        #else
        let swiftlyHome = ProcessInfo.processInfo.environment["SWIFTLY_HOME_DIR"].map { URL(fileURLWithPath: $0) }
            ?? home.appending(path: ".local/share/swiftly")
        return [swiftlyHome.appending(path: "toolchains/\(swiftVersion)")]
        #endif
    }

    private func installSDK() throws {
        guard !FileManager.default.fileExists(atPath: sdkRoot.path) else { return }
        // SDKs for other Swift versions, left by earlier versions of the plugin, are a few hundred
        // megabytes each
        let fileManager = FileManager.default
        for name in (try? fileManager.contentsOfDirectory(atPath: sdksDirectory.path)) ?? [] where name.hasSuffix(".artifactbundle") {
            try? fileManager.removeItem(at: sdksDirectory.appending(path: name))
        }
        print("Downloading Swift's WebAssembly SDK")
        try Command.downloadArchive(Self.sdkURL, sha256: Self.sdkChecksum, into: sdksDirectory)
    }

    private func installBinaryen(in workDirectory: URL) throws {
        guard !FileManager.default.isExecutableFile(atPath: wasmOpt.path) else { return }
        #if os(macOS)
        let system = "macos"
        #else
        let system = "linux"
        #endif
        #if arch(arm64)
        let architecture = system == "macos" ? "arm64" : "aarch64"
        #else
        let architecture = "x86_64"
        #endif
        let platform = "\(architecture)-\(system)"
        guard let checksum = Self.binaryenChecksums[platform] else {
            throw CustomizerError("There's no Binaryen build for \(platform).")
        }
        print("Downloading Binaryen")
        let name = "binaryen-version_\(Self.binaryenVersion)-\(platform).tar.gz"
        let url = URL(string: "https://github.com/WebAssembly/binaryen/releases/download/version_\(Self.binaryenVersion)/\(name)")!
        try Command.downloadArchive(url, sha256: checksum, into: workDirectory)
    }

    /// With C++ interop, the SDK's libc module and libc++'s own header modules both claim
    /// inttypes.h and complex.h, which makes a module cycle. Making those two textual in the libc
    /// module breaks it.
    private func patchModuleMap() throws {
        let moduleMap = sdkLibraries.appending(path: "wasm32/wasi-libc.modulemap")
        let original = try String(contentsOf: moduleMap, encoding: .utf8)
        var patched = original
        for header in ["inttypes.h", "complex.h"] {
            patched = patched.replacingOccurrences(of: "\n  header \"\(header)\"", with: "\n  textual header \"\(header)\"")
        }
        if patched != original {
            try patched.write(to: moduleMap, atomically: true, encoding: .utf8)
        }
    }

    /// The SDK ships the Cxx module's library only with its shared libraries, where static linking
    /// doesn't look, so it's copied next to the static ones. This target has no C++ exceptions, so
    /// stubs that turn a C++ throw into a trap go into the same archive.
    private func installCxxRuntime(support: URL) throws {
        let library = sdkLibraries.appending(path: "libswiftCxx.a")
        guard !FileManager.default.fileExists(atPath: library.path) else { return }

        let build = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: build) }

        let archive = build.appending(path: "libswiftCxx.a")
        try FileManager.default.copyItem(at: sharedSDKLibraries.appending(path: "libswiftCxx.a"), to: archive)
        let stubs = build.appending(path: "cxa_stubs.o")
        try compileC(support.appending(path: "cxa_stubs.c"), to: stubs)
        try Command(binaries.appending(path: "llvm-ar"), ["r", archive.path, stubs.path]).run()
        try FileManager.default.moveItem(at: archive, to: library)
    }

    /// Foundation links ICU, whose data alone is 34 MB. Cadova formats nothing for a locale, so the
    /// data is replaced with an empty stand-in. Anything that does need it (DateFormatter,
    /// NumberFormatter and the like) stops the program instead.
    private func leaveOutICUData(support: URL) throws {
        let marker = sdkLibraries.appending(path: ".icu-data-stubbed")
        guard !FileManager.default.fileExists(atPath: marker.path) else { return }
        print("Leaving ICU's data out of the SDK")

        let build = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: build) }

        // The stand-in replaces the archive member that holds the data, so it takes its name
        let member = "icu_packaged_data.cpp.obj"
        try compileC(support.appending(path: "icu_data_stub.c"), to: build.appending(path: member))
        let archive = sdkLibraries.appending(path: "lib_FoundationICU.a")
        let ar = binaries.appending(path: "llvm-ar")
        try Command(ar, ["d", archive.path, member]).run()
        try Command(ar, ["r", archive.path, member], in: build).run()
        FileManager.default.createFile(atPath: marker.path, contents: nil)
    }

    private func compileC(_ source: URL, to object: URL) throws {
        try Command(binaries.appending(path: "clang"), [
            "--target=wasm32-wasip1", "--sysroot", sysroot.path, "-O2", "-c", source.path, "-o", object.path,
        ]).run()
    }

    /// Builds an executable product of a package for WebAssembly and returns the linked module.
    func build(product: String, packageDirectory: URL, scratchDirectory: URL) throws -> URL {
        let swift = binaries.appending(path: "swift")
        let options = [
            "--package-path", packageDirectory.path, "--scratch-path", scratchDirectory.path,
            "--swift-sdks-path", sdksDirectory.path, "--swift-sdk", Self.sdkName, "-c", "release",
            // The plugin already runs in a sandbox, and macOS can't start one inside another
            "--disable-sandbox",
            // The sandbox keeps SwiftPM out of its shared caches and configuration, so this build
            // keeps its own next to the scratch directory
            "--cache-path", scratchDirectory.appending(path: "../swiftpm/cache").standardizedFileURL.path,
            "--config-path", scratchDirectory.appending(path: "../swiftpm/configuration").standardizedFileURL.path,
            "--security-path", scratchDirectory.appending(path: "../swiftpm/security").standardizedFileURL.path,
            "-Xcc", "-D_WASI_EMULATED_SIGNAL", "-Xcc", "-D_WASI_EMULATED_MMAN", "-Xcc", "-D_WASI_EMULATED_PROCESS_CLOCKS",
        ]

        let binPath = try Command(swift, ["build", "--show-bin-path"] + options).output()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let module = URL(fileURLWithPath: binPath).appending(path: "\(product).wasm")
        // SwiftPM doesn't see changes to the SDK's libraries, such as the ones made above, so always relink
        try? FileManager.default.removeItem(at: module)

        try Command(swift, ["build", "--product", product] + options).run()
        return module
    }

    /// Writes a size-optimized copy of a module. Names only serve stack traces, and Binaryen then
    /// removes code nothing can reach and merges the many identical functions Swift generates,
    /// without changing what the code does.
    func optimize(_ module: URL, to output: URL) throws {
        try Command(wasmOpt, ["-Oz", "--strip-debug", "--strip-producers", module.path, "-o", output.path]).run()
    }
}
