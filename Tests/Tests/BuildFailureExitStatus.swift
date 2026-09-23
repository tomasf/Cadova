import Foundation
import Testing
@testable import Cadova

/// A geometry that can never be built: the file it imports does not exist.
private var unbuildableGeometry: any Geometry3D {
    Import(model: URL(filePath: "/nonexistent/cadova-missing-model.3mf"))
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// Whether making a directory read-only actually stops writes into it.
///
/// POSIX permission bits do not govern directory writes on Windows, so a directory made read-only
/// there stays writable, and a test built on that premise would assert the opposite of what
/// happens. Skipping is honest where passing would not be.
private let readOnlyDirectoriesAreEnforced = {
    #if os(Windows)
    false
    #else
    true
    #endif
}()

struct BuildFailureExitStatusTests {

    // MARK: - The exit status

    @Test func `a project whose model fails exits with a non-zero status`() async throws {
        await #expect(processExitsWith: .failure) {
            let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            await Project(root: directory) {
                await Model("good") { Box(10) }
                await Model("bad") { Import(model: URL(filePath: "/nonexistent/cadova-missing-model.3mf")) }
            }
        }
    }

    @Test func `a project whose models all build exits with a zero status`() async throws {
        await #expect(processExitsWith: .success) {
            let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            await Project(root: directory) {
                await Model("good") { Box(10) }
            }
        }
    }

    @Test(.enabled(if: readOnlyDirectoriesAreEnforced))
    func `a project that cannot create its output directory exits with a non-zero status`() async throws {
        await #expect(processExitsWith: .failure) {
            let parent = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: parent.path)

            await Project(root: parent.appending(path: "models")) {
                await Model("box") { Box(10) }
            }
        }
    }

    @Test(.enabled(if: readOnlyDirectoriesAreEnforced))
    func `a group that cannot create its directory exits with a non-zero status`() async throws {
        await #expect(processExitsWith: .failure) {
            let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)

            await Project(root: directory) {
                await Group("parts") {
                    await Model("box") { Box(10) }
                }
            }
        }
    }

    /// The carve-out, asserted rather than assumed. A model that builds to nothing under some
    /// condition is a reasonable thing to write, so it stays a logged error and nothing more.
    /// Making it a failure is a separate argument from this one.
    @Test func `a model containing no geometry does not change the exit status`() async throws {
        await #expect(processExitsWith: .success) {
            let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            await Project(root: directory) {
                await Model("empty") {}
            }
        }
    }

    // MARK: - What still happens around the failure

    /// The build runs in the child process, so the directory is made here and captured into it.
    /// What the child wrote is still on disk once it has exited, which is what this asserts.
    @Test func `a failing model does not stop the models beside it`() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        await #expect(processExitsWith: .failure) { [directory = directory as URL] in
            await Project(root: directory) {
                await Model("good") { Box(10) }
                await Model("bad") { unbuildableGeometry }
            }
        }

        let files = Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
        #expect(files.contains("good.3mf"))
        #expect(files.contains("bad.3mf") == false)
    }

    @Test(.enabled(if: readOnlyDirectoriesAreEnforced))
    func `a group whose directory cannot be created does not stop its siblings`() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let blocked = directory.appending(path: "blocked")
        try FileManager.default.createDirectory(at: blocked, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: blocked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: blocked.path) }

        await #expect(processExitsWith: .failure) { [directory = directory as URL] in
            await Project(root: directory) {
                await Group("blocked") {
                    await Group("inner") {
                        await Model("unreachable") { Box(10) }
                    }
                }
                await Model("sibling") { Box(10) }
            }
        }

        let files = Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
        #expect(files.contains("sibling.3mf"))
        #expect(try FileManager.default.contentsOfDirectory(atPath: blocked.path).isEmpty)
    }
}
