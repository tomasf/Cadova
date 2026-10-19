import Foundation

/// The swift.org toolchain, Swift WebAssembly SDK and Binaryen a customizer is built with.
///
/// The plugin keeps its own copy of the SDK in its work directory and patches it, so the patches
/// never touch an SDK installed for other projects.
struct WebAssemblyToolchain {
    /// The Swift version customizers are built with, from Support/swift-version, where Cadova's GitHub
    /// action reads it too. When changing it, update `sdkChecksum`, and check the SDK's licenses in
    /// `LicenseNotices.bundled`.
    static let swiftVersion: String = {
        let file = GenerateCustomizer.pluginDirectory.appending(path: "Support/swift-version")
        guard let text = try? String(contentsOf: file, encoding: .utf8) else {
            preconditionFailure("The plugin's Swift version file is missing: \(file.fileSystemPath)")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }()
    static let sdkName = "swift-\(swiftVersion)-RELEASE_wasm"
    static let sdkURL = URL(string: "https://download.swift.org/swift-\(swiftVersion)-release/wasm-sdk/swift-\(swiftVersion)-RELEASE/\(sdkName).artifactbundle.tar.gz")!
    static let sdkChecksum = "f07b7be3c586d92d7a07051fc6d303b87ebea67eadc40640ba59d5a8b79aa86d"

    static let binaryenVersion = "133"
    static let binaryenChecksums = [
        "arm64-macos": "ad66da82ac13f163e424b1643f16c6dfcccc98b5966296b43e52d3cab04f84a8",
        "x86_64-macos": "13a9b90be775c6389ce3d1f879cb8627bea56708ba8c122983941d53a8199b95",
        "x86_64-linux": "2dc9c7813f5375db93d96ead4b78222fcc3e2677bbb832297af4797782a37489",
        "aarch64-linux": "89c07ea56faf38d0fbecf36ca8ec0721756716185f265b568e133d427f299bf8",
        "x86_64-windows": "17a2cbeac6b5693c5fbafab3838d3c65fd9c1eb38b05f5baec6c657e8c84995b",
        "arm64-windows": "492a8e1847a0be1554bb9a7f384227981d60bc013aedc02d8ba1372c3943178c",
    ]

    /// A program's file name: Windows' end in .exe.
    static func executableName(_ name: String) -> String {
        #if os(Windows)
        "\(name).exe"
        #else
        name
        #endif
    }

    /// The toolchain's `usr/bin`
    let binaries: URL
    let sdksDirectory: URL
    let wasmOpt: URL
    /// A directory whose clang the Swift driver links with instead of the toolchain's, if any
    var linkerTools: URL? = nil

    var sdkRoot: URL { sdksDirectory.appending(path: "\(Self.sdkName).artifactbundle/\(Self.sdkName)/wasm32-unknown-wasip1") }
    var sysroot: URL { sdkRoot.appending(path: "WASI.sdk") }
    var swiftResources: URL { sdkRoot.appending(path: "swift.xctoolchain/usr/lib/swift_static") }
    var sdkLibraries: URL { swiftResources.appending(path: "wasi") }
    var sharedSDKLibraries: URL { sdkRoot.appending(path: "swift.xctoolchain/usr/lib/swift/wasi") }

    /// Finds the toolchain, and downloads and patches the SDK and Binaryen if they're not in the
    /// work directory yet.
    static func prepare(in workDirectory: URL, support: URL) throws -> Self {
        var toolchain = Self(
            binaries: try locateToolchain(),
            sdksDirectory: workDirectory.appending(path: "swift-sdks"),
            wasmOpt: workDirectory.appending(path: "binaryen-version_\(binaryenVersion)/bin/\(executableName("wasm-opt"))")
        )
        #if os(Windows)
        try toolchain.checkForOtherVersions()
        #endif
        try toolchain.checkVersion()
        try toolchain.installSDK()
        try toolchain.installBinaryen(in: workDirectory)
        try toolchain.patchModuleMap()
        try toolchain.installCxxRuntime(support: support)
        try toolchain.leaveOutICUData(support: support)
        #if os(Windows)
        toolchain.linkerTools = try toolchain.installQuotingClang(in: workDirectory, support: support)
        #endif
        return toolchain
    }

    /// The SDK only works with the exact Swift version it was built for, and another one fails deep in
    /// the build with errors that don't say why, so a toolchain of the wrong version stops here. The
    /// standard locations are named after the version, so this mostly catches CADOVA_WASM_TOOLCHAIN
    /// pointing at another one, such as one installed by a GitHub action of another version.
    private func checkVersion() throws {
        let swift = binaries.appending(path: Self.executableName("swift"))
        let output = (try? Command(swift, ["--version"], environment: swiftEnvironment).output()) ?? ""
        // "Swift version 6.4 (swift-6.4-RELEASE)", with "Apple " in front on macOS
        guard let start = output.range(of: "(swift-")?.upperBound,
              let end = output[start...].range(of: "-RELEASE)")?.lowerBound else {
            print("warning: Couldn't tell which version of Swift \(swift.fileSystemPath) is; building with it anyway.")
            return
        }
        let found = String(output[start..<end])
        guard Self.components(of: found) != Self.components(of: Self.swiftVersion) else { return }

        let isExplicit = ProcessInfo.processInfo.environment["CADOVA_WASM_TOOLCHAIN"] != nil
        let location = isExplicit ? "CADOVA_WASM_TOOLCHAIN points at Swift \(found)" : "the toolchain found is Swift \(found)"
        let toolchain = binaries.deletingLastPathComponent().deletingLastPathComponent()
        let advice = isExplicit
            ? " If Cadova's GitHub action installed it, commit Package.resolved, which the action reads to install the right one."
            : ""
        throw CustomizerError("""
            This version of Cadova builds customizers with Swift \(Self.swiftVersion), but \(location), \
            in \(toolchain.fileSystemPath). Swift's WebAssembly SDK only works with the exact version it \
            was built for.\(advice)
            """)
    }

    /// A version's numbers, with missing ones as zeros, so that "6.4" and "6.4.0" are the same
    private static func components(of version: String) -> [Int] {
        let numbers = version.split(separator: ".").map { Int($0) ?? -1 }
        return numbers + Array(repeating: 0, count: max(0, 3 - numbers.count))
    }

    private static func locateToolchain() throws -> URL {
        let fileManager = FileManager.default
        let isToolchain = { (directory: URL) in
            fileManager.isExecutableFile(atPath: directory.appending(path: "usr/bin/\(executableName("swift"))").path)
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
        #elseif os(Windows)
        let package = "  https://download.swift.org/swift-\(swiftVersion)-release/windows10/swift-\(swiftVersion)-RELEASE/swift-\(swiftVersion)-RELEASE-windows10.exe"
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
        #elseif os(Windows)
        // swift.org's installer puts each version in a folder of its own, per user or for everyone
        let environment = ProcessInfo.processInfo.environment
        let roots = [
            environment["LOCALAPPDATA"].map { URL(fileURLWithPath: $0).appending(path: "Programs/Swift") },
            environment["ProgramFiles"].map { URL(fileURLWithPath: $0).appending(path: "Swift") },
        ].compactMap { $0 }
        return roots.flatMap { root in
            ["\(swiftVersion)+Asserts", swiftVersion].map { root.appending(path: "Toolchains/\($0)") }
        }
        #else
        let swiftlyHome = ProcessInfo.processInfo.environment["SWIFTLY_HOME_DIR"].map { URL(fileURLWithPath: $0) }
            ?? home.appending(path: ".local/share/swiftly")
        return [swiftlyHome.appending(path: "toolchains/\(swiftVersion)")]
        #endif
    }

    #if os(Windows)
    /// SwiftPM's build system registers every Swift version installed next to the toolchain, and
    /// fails when there's more than one ("platform 'windows' already registered"), so the build
    /// would stop with that before anything else.
    private func checkForOtherVersions() throws {
        // binaries is <root>/Toolchains/<version>/usr/bin
        let root = binaries.appending(path: "../../../..").standardizedFileURL
        let toolchain = binaries.appending(path: "../..").standardizedFileURL.lastPathComponent
        let others = ["Toolchains", "Platforms"].flatMap { folder in
            let directory = root.appending(path: folder)
            return ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
                .filter { $0 != toolchain && $0 != Self.swiftVersion }
                .map { directory.appending(path: $0).fileSystemPath }
        }
        guard !others.isEmpty else { return }
        throw CustomizerError("""
            Other versions of Swift are installed next to Swift \(Self.swiftVersion), and SwiftPM can't \
            build with several versions installed side by side on Windows. Uninstall the other \
            versions (in Settings, under Apps), and build again.

            Found:
            \(others.map { "  " + $0 }.joined(separator: "\n"))
            """)
    }
    #endif

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
        #elseif os(Windows)
        let system = "windows"
        #else
        let system = "linux"
        #endif
        #if arch(arm64)
        let architecture = system == "linux" ? "aarch64" : "arm64"
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
        try Command(binaries.appending(path: Self.executableName("llvm-ar")), ["r", archive.fileSystemPath, stubs.fileSystemPath]).run()
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
        let ar = binaries.appending(path: Self.executableName("llvm-ar"))
        try Command(ar, ["d", archive.fileSystemPath, member]).run()
        try Command(ar, ["r", archive.fileSystemPath, member], in: build).run()
        FileManager.default.createFile(atPath: marker.path, contents: nil)
    }

    private func compileC(_ source: URL, to object: URL) throws {
        try Command(binaries.appending(path: Self.executableName("clang")), [
            "--target=wasm32-wasip1", "--sysroot", sysroot.fileSystemPath, "-O2", "-c", source.fileSystemPath, "-o", object.fileSystemPath,
        ]).run()
    }

    #if os(Windows)
    /// Builds the stand-in for clang described in clang_rsp_quoting.c with the toolchain's own clang,
    /// unless it's already newer than its source, and returns the directory it's in.
    private func installQuotingClang(in workDirectory: URL, support: URL) throws -> URL {
        let fileManager = FileManager.default
        let directory = workDirectory.appending(path: "linker-tools")
        let source = support.appending(path: "clang_rsp_quoting.c")
        let standIn = directory.appending(path: Self.executableName("clang"))
        let realClang = binaries.appending(path: Self.executableName("clang"))
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(realClang.fileSystemPath.utf8).write(to: directory.appending(path: "real-clang.txt"))

        let modified = { (file: URL) in (try? fileManager.attributesOfItem(atPath: file.path)[.modificationDate]) as? Date }
        if let built = modified(standIn), let written = modified(source), built > written {
            return directory
        }
        try Command(realClang, ["-O2", "-fuse-ld=lld", source.fileSystemPath, "-o", standIn.fileSystemPath]).run()
        return directory
    }
    #endif

    /// The environment the toolchain's swift runs in. On Windows, the Swift runtime is a set of DLLs
    /// found through PATH, and the toolchain's swift quietly fails with another version's runtime,
    /// such as the one running this plugin, so its own version's comes first.
    private var swiftEnvironment: [String: String?] {
        // On macOS, a package that depends on Cadova gets its prebuilt XCFramework once one is
        // published, which only has macOS in it, so Cadova builds from source for WebAssembly
        var environment: [String: String?] = ["CADOVA_BUILD_FROM_SOURCE": "1"]
        #if os(Windows)
        // binaries is <root>/Toolchains/<version>/usr/bin, and the runtime is in <root>/Runtimes
        let root = binaries.appending(path: "../../../..").standardizedFileURL
        let runtime = root.appending(path: "Runtimes/\(Self.swiftVersion)/usr/bin")
        guard FileManager.default.fileExists(atPath: runtime.path) else { return environment }
        // Windows' variable names ignore case, but the environment Foundation hands over doesn't
        let inherited = ProcessInfo.processInfo.environment
        let name = inherited.keys.first { $0.uppercased() == "PATH" } ?? "Path"
        let path = [runtime.fileSystemPath, binaries.fileSystemPath] + [inherited[name]].compactMap { $0 }
        environment[name] = path.joined(separator: ";")
        #endif
        return environment
    }

    /// Builds an executable product of a package for WebAssembly and returns the linked module.
    func build(product: String, packageDirectory: URL, scratchDirectory: URL) throws -> URL {
        let swift = binaries.appending(path: Self.executableName("swift"))
        var options = [
            "--package-path", packageDirectory.fileSystemPath, "--scratch-path", scratchDirectory.fileSystemPath,
            "--swift-sdks-path", sdksDirectory.fileSystemPath, "--swift-sdk", Self.sdkName, "-c", "release",
            // The plugin already runs in a sandbox, and macOS can't start one inside another
            "--disable-sandbox",
            // The sandbox keeps SwiftPM out of its shared caches and configuration, so this build
            // keeps its own next to the scratch directory
            "--cache-path", scratchDirectory.appending(path: "../swiftpm/cache").standardizedFileURL.fileSystemPath,
            "--config-path", scratchDirectory.appending(path: "../swiftpm/configuration").standardizedFileURL.fileSystemPath,
            "--security-path", scratchDirectory.appending(path: "../swiftpm/security").standardizedFileURL.fileSystemPath,
            "-Xcc", "-D_WASI_EMULATED_SIGNAL", "-Xcc", "-D_WASI_EMULATED_MMAN", "-Xcc", "-D_WASI_EMULATED_PROCESS_CLOCKS",
        ]
        #if os(Windows)
        // Swift's Windows toolchains are built with assertions, so the compiler verifies its own SIL
        // after every optimization, which the macOS and Linux toolchains don't. With Swift 6.4, that
        // verification fails on Cadova ("struct operand type does not match field type") and stops
        // the build, so it's turned off, as it is in the other toolchains.
        options += ["-Xswiftc", "-Xfrontend", "-Xswiftc", "-sil-verify-none"]
        #endif
        if let linkerTools {
            options += ["-Xswiftc", "-tools-directory", "-Xswiftc", linkerTools.fileSystemPath]
        }

        let binPath = try Command(swift, ["build", "--show-bin-path"] + options, environment: swiftEnvironment).output()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let module = URL(fileURLWithPath: binPath).appending(path: "\(product).wasm")
        // SwiftPM doesn't see changes to the SDK's libraries, such as the ones made above, so always relink
        try? FileManager.default.removeItem(at: module)

        try Command(swift, ["build", "--product", product] + options, environment: swiftEnvironment).run()
        return module
    }

    /// Writes a size-optimized copy of a module. Names only serve stack traces, and Binaryen then
    /// removes code nothing can reach and merges the many identical functions Swift generates,
    /// without changing what the code does.
    func optimize(_ module: URL, to output: URL) throws {
        try Command(wasmOpt, ["-Oz", "--strip-debug", "--strip-producers", module.fileSystemPath, "-o", output.fileSystemPath]).run()
    }
}
