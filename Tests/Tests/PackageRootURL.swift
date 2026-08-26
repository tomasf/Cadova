import Foundation
import Testing
@testable import Cadova

/// `packageRootURL` locates the Swift package that owns a source file, which is how `Project` and
/// `Model` decide where to write output when no explicit root is given. It probes for a `Package.swift`
/// manifest rather than pattern-matching on directory names, so layouts that don't follow the
/// `Sources/` convention resolve correctly instead of silently landing in the wrong directory.
struct PackageRootURLTests {
    /// Builds a throwaway directory tree. Each entry in `manifests` gets a `Package.swift`, and
    /// `sourceFile` is created as an empty file. Paths are relative to the returned root.
    private func makeTree(
        manifests: [String],
        sourceFile: String
    ) throws -> (root: URL, sourceURL: URL) {
        let fileManager = FileManager()
        let root = fileManager.temporaryDirectory
            .appending(path: "CadovaPackageRoot-\(UUID().uuidString)", directoryHint: .isDirectory)

        for manifest in manifests {
            let directory = manifest.isEmpty ? root : root.appending(path: manifest, directoryHint: .isDirectory)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data().write(to: directory.appending(path: "Package.swift"))
        }

        let sourceURL = root.appending(path: sourceFile)
        try fileManager.createDirectory(
            at: sourceURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data().write(to: sourceURL)

        return (root, sourceURL)
    }

    private func removeTree(at root: URL) {
        try? FileManager().removeItem(at: root)
    }

    @Test func findsRootOfConventionalLayout() throws {
        let tree = try makeTree(manifests: [""], sourceFile: "Sources/Widgets/Widget.swift")
        defer { removeTree(at: tree.root) }

        #expect(tree.sourceURL.packageRootURL?.standardizedFileURL.path == tree.root.standardizedFileURL.path)
    }

    /// A directory named `Sources` nested inside the target used to win over the real root.
    @Test func ignoresNestedSourcesDirectory() throws {
        let tree = try makeTree(manifests: [""], sourceFile: "Sources/Widgets/Sources/Widget.swift")
        defer { removeTree(at: tree.root) }

        #expect(tree.sourceURL.packageRootURL?.standardizedFileURL.path == tree.root.standardizedFileURL.path)
    }

    /// Targets declared with a custom `path:` need not live under `Sources` at all.
    @Test func findsRootWithoutSourcesDirectory() throws {
        let tree = try makeTree(manifests: [""], sourceFile: "Widgets/Widget.swift")
        defer { removeTree(at: tree.root) }

        #expect(tree.sourceURL.packageRootURL?.standardizedFileURL.path == tree.root.standardizedFileURL.path)
    }

    /// A package checked out inside another package resolves to the innermost one that owns the file.
    @Test func prefersInnermostPackage() throws {
        let tree = try makeTree(
            manifests: ["", "Examples/Demo"],
            sourceFile: "Examples/Demo/Sources/App/App.swift"
        )
        defer { removeTree(at: tree.root) }

        let expected = tree.root.appending(path: "Examples/Demo", directoryHint: .isDirectory)
        #expect(tree.sourceURL.packageRootURL?.standardizedFileURL.path == expected.standardizedFileURL.path)
    }

    /// A *directory* named `Package.swift` is not a manifest, and must not be mistaken for one.
    @Test func ignoresDirectoryNamedLikeManifest() throws {
        let tree = try makeTree(manifests: [""], sourceFile: "Nested/Widgets/Widget.swift")
        defer { removeTree(at: tree.root) }

        let decoy = tree.root.appending(path: "Nested/Package.swift", directoryHint: .isDirectory)
        try FileManager().createDirectory(at: decoy, withIntermediateDirectories: true)

        #expect(tree.sourceURL.packageRootURL?.standardizedFileURL.path == tree.root.standardizedFileURL.path)
    }

    /// The walk must terminate at the filesystem root rather than spinning or walking off the top.
    @Test func terminatesAtFilesystemRoot() throws {
        #expect(URL(filePath: "/Widget.swift").packageRootURL == nil)
        #expect(URL(filePath: "/").packageRootURL == nil)
    }

    @Test func returnsNilWithoutManifest() throws {
        let tree = try makeTree(manifests: [], sourceFile: "Sources/Widgets/Widget.swift")
        defer { removeTree(at: tree.root) }

        #expect(tree.sourceURL.packageRootURL == nil)
    }
}
