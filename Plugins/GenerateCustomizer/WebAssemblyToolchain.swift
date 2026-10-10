import Foundation

/// The swift.org toolchain, Swift WebAssembly SDK and Binaryen a customizer is built with.
///
/// The plugin keeps its own copy of the SDK in its work directory and patches it, so the patches
/// never touch an SDK installed for other projects.
struct WebAssemblyToolchain {
    static let swiftVersion = "6.3.2"
    static let sdkName = "swift-\(swiftVersion)-RELEASE_wasm"
    static let sdkURL = URL(string: "https://download.swift.org/swift-\(swiftVersion)-release/wasm-sdk/swift-\(swiftVersion)-RELEASE/\(sdkName).artifactbundle.tar.gz")!
    static let sdkChecksum = "a61f0584c93283589f8b2f42db05c1f9a182b506c2957271402992655591dd7c"

    static let binaryenVersion = "133"
    static let binaryenChecksums = [
        "arm64-macos": "ad66da82ac13f163e424b1643f16c6dfcccc98b5966296b43e52d3cab04f84a8",
        "x86_64-macos": "13a9b90be775c6389ce3d1f879cb8627bea56708ba8c122983941d53a8199b95",
        "x86_64-linux": "2dc9c7813f5375db93d96ead4b78222fcc3e2677bbb832297af4797782a37489",
        "aarch64-linux": "89c07ea56faf38d0fbecf36ca8ec0721756716185f265b568e133d427f299bf8",
    ]

    /// The sources of Swift's Cxx module, from the same Swift release as the toolchain
    static let cxxSourcesURL = URL(string: "https://raw.githubusercontent.com/swiftlang/swift/swift-\(swiftVersion)-RELEASE/stdlib/public/Cxx/")!
    static let cxxSources = [
        "CxxConvertibleToBool.swift": "b675ead5369d62a67728b6f59040f312a3b8a84ab897eee06c6202252420aaaf",
        "CxxConvertibleToCollection.swift": "4e20b077c6d545c8b1ee5389d62e922a37a16dbfbf1518e37aae264f9d0d6dac",
        "CxxDictionary.swift": "108a8a101072314450bfcb492e023a5fbdff142643c019a39b63ec649f3b4216",
        "CxxOptional.swift": "8ab992e1e93223beb2abb6a9c65fafdfc274375e414a49e48a4999dc058c95a4",
        "CxxPair.swift": "5c13934250c3bea9ea223f10c1b36af1ac6d1da9b84747a7c5fde5185aff02ab",
        "CxxRandomAccessCollection.swift": "406e02b0fc3f3700bcad4602807bac323cabe465fb38889ea30bb99790ac53b1",
        "CxxSequence.swift": "4e95d1a7b71d61289da67a230cb761d68a343fc5e5eb2b0f0a719056f20b2e6a",
        "CxxSet.swift": "2d69bc8ff07b3f536317c06785e8d80d15aa7daa0abeaa5621da8dfda01b92c6",
        "CxxSpan.swift": "3cbfe9cf3247ccbb165edba7785970392cc7a1e598879ccd3ca571e43b42e8b1",
        "CxxVector.swift": "123069c226c9d55892e8163ce453d0aef735491c3611eeb04de0654457d24702",
        "UnsafeCxxIterators.swift": "a62db5dccec886d8afdbec9dde4cfc2312af952f050c6c8b5865e058d1d36fff",
    ]

    /// The toolchain's `usr/bin`
    let binaries: URL
    let sdksDirectory: URL
    let wasmOpt: URL

    var sdkRoot: URL { sdksDirectory.appending(path: "\(Self.sdkName).artifactbundle/\(Self.sdkName)/wasm32-unknown-wasip1") }
    var sysroot: URL { sdkRoot.appending(path: "WASI.sdk") }
    var swiftResources: URL { sdkRoot.appending(path: "swift.xctoolchain/usr/lib/swift_static") }
    var sdkLibraries: URL { swiftResources.appending(path: "wasi") }

    /// swift.org toolchains can't compile manifests against the macOS SDK in Xcode 27, so on macOS
    /// the host side uses the Command Line Tools when they're installed. SwiftPM gives plugins an
    /// SDKROOT for Xcode's SDK, which would win over DEVELOPER_DIR, so that goes.
    var hostEnvironment: [String: String?] {
        #if os(macOS)
        let commandLineTools = "/Library/Developer/CommandLineTools"
        if FileManager.default.fileExists(atPath: commandLineTools) {
            return ["DEVELOPER_DIR": commandLineTools, "SDKROOT": nil]
        }
        #endif
        return [:]
    }

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
        try toolchain.buildCxxRuntime(support: support)
        try toolchain.leaveOutICUData(support: support)
        return toolchain
    }

    private static func locateToolchain() throws -> URL {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        var candidates: [URL] = []
        if let path = ProcessInfo.processInfo.environment["CADOVA_WASM_TOOLCHAIN"] {
            candidates.append(URL(fileURLWithPath: path))
        }
        #if os(macOS)
        let bundle = "swift-\(swiftVersion)-RELEASE.xctoolchain"
        candidates += [
            home.appending(path: "Library/Developer/Toolchains/\(bundle)"),
            URL(fileURLWithPath: "/Library/Developer/Toolchains/\(bundle)"),
        ]
        #else
        let swiftlyHome = ProcessInfo.processInfo.environment["SWIFTLY_HOME_DIR"].map { URL(fileURLWithPath: $0) }
            ?? home.appending(path: ".local/share/swiftly")
        candidates.append(swiftlyHome.appending(path: "toolchains/\(swiftVersion)"))
        #endif

        for candidate in candidates {
            let binaries = candidate.appending(path: "usr/bin")
            if fileManager.isExecutableFile(atPath: binaries.appending(path: "swift").path) {
                return binaries
            }
        }
        throw CustomizerError("""
            Building for WebAssembly needs Swift \(swiftVersion) from swift.org, which wasn't found. \
            Install it with `swiftly install \(swiftVersion)`, or set CADOVA_WASM_TOOLCHAIN to the \
            toolchain's directory.
            """)
    }

    private func installSDK() throws {
        guard !FileManager.default.fileExists(atPath: sdkRoot.path) else { return }
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

    /// The SDK has the Cxx module's interface but not its library, so build it from the same
    /// sources. It goes into the SDK, where the linker looks for it.
    private func buildCxxRuntime(support: URL) throws {
        let library = sdkLibraries.appending(path: "libswiftCxx.a")
        guard !FileManager.default.fileExists(atPath: library.path) else { return }
        print("Building the Cxx runtime for WebAssembly")

        let build = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: build) }

        var sources: [URL] = []
        for (name, checksum) in Self.cxxSources.sorted(by: { $0.key < $1.key }) {
            let source = build.appending(path: name)
            try Command.download(Self.cxxSourcesURL.appending(path: name), to: source, sha256: checksum)
            sources.append(source)
        }

        let object = build.appending(path: "Cxx.o")
        try Command(binaries.appending(path: "swiftc"), [
            "-target", "wasm32-unknown-wasip1", "-sdk", sysroot.path, "-resource-dir", swiftResources.path,
            "-static-stdlib", "-module-name", "Cxx", "-parse-as-library", "-O", "-wmo", "-enable-library-evolution",
            "-cxx-interoperability-mode=default", "-strict-memory-safety",
            "-enable-experimental-feature", "BuiltinModule", "-enable-experimental-feature", "AllowUnsafeAttribute",
            "-enable-experimental-feature", "Lifetimes", "-enable-experimental-feature", "LifetimeDependence",
            "-Xcc", "-nostdinc++", "-Xfrontend", "-disable-implicit-cxx-module-import",
            // The sources are the standard library's own, and warn about things only its build defines
            "-suppress-warnings",
            "-c", "-o", object.path,
        ] + sources.map(\.path), environment: hostEnvironment).run()

        let stubs = build.appending(path: "cxa_stubs.o")
        try compileC(support.appending(path: "cxa_stubs.c"), to: stubs)
        try Command(binaries.appending(path: "llvm-ar"), ["rcs", library.path, object.path, stubs.path]).run()
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
        let module = scratchDirectory.appending(path: "wasm32-unknown-wasip1/release/\(product).wasm")
        // SwiftPM doesn't see changes to the SDK's libraries, such as the ones made above, so always relink
        try? FileManager.default.removeItem(at: module)

        try Command(binaries.appending(path: "swift"), [
            "build", "--package-path", packageDirectory.path, "--scratch-path", scratchDirectory.path,
            "--swift-sdks-path", sdksDirectory.path, "--swift-sdk", Self.sdkName,
            "--product", product, "-c", "release",
            // The plugin already runs in a sandbox, and macOS can't start one inside another
            "--disable-sandbox",
            // The sandbox keeps SwiftPM out of its shared caches and configuration, so this build
            // keeps its own next to the scratch directory
            "--cache-path", scratchDirectory.appending(path: "../swiftpm/cache").standardizedFileURL.path,
            "--config-path", scratchDirectory.appending(path: "../swiftpm/configuration").standardizedFileURL.path,
            "--security-path", scratchDirectory.appending(path: "../swiftpm/security").standardizedFileURL.path,
            "-Xcc", "-D_WASI_EMULATED_SIGNAL", "-Xcc", "-D_WASI_EMULATED_MMAN", "-Xcc", "-D_WASI_EMULATED_PROCESS_CLOCKS",
        ], environment: hostEnvironment).run()
        return module
    }

    /// Writes a size-optimized copy of a module. Names only serve stack traces, and Binaryen then
    /// removes code nothing can reach and merges the many identical functions Swift generates,
    /// without changing what the code does.
    func optimize(_ module: URL, to output: URL) throws {
        try Command(wasmOpt, ["-Oz", "--strip-debug", "--strip-producers", module.path, "-o", output.path]).run()
    }
}
