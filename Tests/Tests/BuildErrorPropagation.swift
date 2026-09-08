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
/// there stays writable, and a test built on that premise would assert the opposite of what happens.
/// Skipping is honest where passing would not be.
private let readOnlyDirectoriesAreEnforced = {
    #if os(Windows)
    false
    #else
    true
    #endif
}()

/// Makes `directory` unwritable for the duration of `body`, then puts it back so that it can be
/// deleted again.
@discardableResult
private func withReadOnlyDirectory<T>(_ directory: URL, _ body: () async throws -> T) async rethrows -> T {
    try? FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path) }
    return try await body()
}

struct BuildErrorPropagationTests {
    init() {
        Platform.revealingFilesDisabled = true
    }

    // MARK: - A failing model is reported to whoever started the build

    @Test func `a project reports a failing model while still writing the good ones`() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let outcome = await BuildFailureBehavior.report.whileCurrent {
            await Project(root: directory) {
                await Model("good") { Box(10) }
                await Model("bad") { unbuildableGeometry }
            }
        }

        let files = Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
        #expect(files.contains("good.3mf"))
        #expect(files.contains("bad.3mf") == false)

        #expect(outcome.succeeded == false)
        let failure = try #require(outcome.failures.first)
        #expect(outcome.failures.count == 1)
        #expect(failure.modelName == "bad")
        // The 3MF provider generates its contents on demand, so the missing import surfaces when
        // the file is produced rather than while the geometry tree is being assembled.
        #expect(failure.stage == .writing)
    }

    @Test func `a model containing no geometry is a failure, not a silent no-op`() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let outcome = await BuildFailureBehavior.report.whileCurrent {
            await Project(root: directory) {
                await Model("empty") {}
            }
        }

        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        #expect(outcome.failures.map(\.modelName) == ["empty"])
        #expect(outcome.failures.first?.underlyingError is BuildError)
    }

    @Test func `a failing model inside a group is named by its full path`() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let outcome = await BuildFailureBehavior.report.whileCurrent {
            await Project(root: directory) {
                await Group("parts") {
                    await Model("bad") { unbuildableGeometry }
                }
            }
        }

        #expect(outcome.failures.map(\.modelName) == ["parts/bad"])
    }

    // MARK: - The process exit status

    @Test func `a project whose model fails exits with a non-zero status`() async throws {
        await #expect(processExitsWith: .failure) {
            Platform.revealingFilesDisabled = true
            let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            await Project(root: directory) {
                await Model("good") { Box(10) }
                await Model("bad") { Import(model: URL(filePath: "/nonexistent/cadova-missing-model.3mf")) }
            }
        }
    }

    @Test func `a standalone model that fails exits with a non-zero status`() async throws {
        await #expect(processExitsWith: .failure) {
            Platform.revealingFilesDisabled = true
            let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            await Model(directory.appending(path: "bad").path) {
                Import(model: URL(filePath: "/nonexistent/cadova-missing-model.3mf"))
            }
        }
    }

    @Test func `a project whose models all succeed exits with a zero status`() async throws {
        await #expect(processExitsWith: .success) {
            Platform.revealingFilesDisabled = true
            let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            await Project(root: directory) {
                await Model("good") { Box(10) }
            }
        }
    }

    // MARK: - An unwritable destination

    @Test(.enabled(if: readOnlyDirectoriesAreEnforced))
    func `a model that cannot be written to a read-only directory reports the failure`() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let outcome = await withReadOnlyDirectory(directory) {
            await BuildFailureBehavior.report.whileCurrent {
                await Project(root: directory) {
                    await Model("locked-out") { Box(10) }
                }
            }
        }

        #expect(outcome.succeeded == false)
        let failure = try #require(outcome.failures.first)
        #expect(failure.stage == .writing)
        #expect(failure.modelName == "locked-out")
        #expect(failure.url?.lastPathComponent == "locked-out.3mf")

        // Nothing at all, not even a partly written file.
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    // MARK: - Directory creation

    @Test(.enabled(if: readOnlyDirectoriesAreEnforced))
    func `a project whose output directory cannot be created reports the failure`() async throws {
        let parent = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let output = parent.appending(path: "output")

        let outcome = await withReadOnlyDirectory(parent) {
            await BuildFailureBehavior.report.whileCurrent {
                await Project(root: output) {
                    await Model("box") { Box(10) }
                }
            }
        }

        #expect(outcome.failures.count == 1)
        #expect(outcome.failures.first?.stage == .creatingDirectory)
        #expect(outcome.failures.first?.url == output)
        #expect(FileManager.default.fileExists(atPath: output.path) == false)
    }

    @Test(.enabled(if: readOnlyDirectoriesAreEnforced))
    func `a group whose subdirectory cannot be created reports the failure`() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let outcome = await withReadOnlyDirectory(directory) {
            await BuildFailureBehavior.report.whileCurrent {
                await Project(root: directory) {
                    await Group("parts") {
                        await Model("box") { Box(10) }
                    }
                }
            }
        }

        // One failure for the directory, rather than one per model that could not be saved into it.
        #expect(outcome.failures.count == 1)
        #expect(outcome.failures.first?.stage == .creatingDirectory)
        #expect(outcome.failures.first?.modelName == "parts")
    }

    @Test(.enabled(if: readOnlyDirectoriesAreEnforced))
    func `a project whose output directory cannot be created exits with a non-zero status`() async throws {
        await #expect(processExitsWith: .failure) {
            Platform.revealingFilesDisabled = true
            let parent = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: parent.path)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path) }

            await Project(root: parent.appending(path: "output")) {
                await Model("box") { Box(10) }
            }
        }
    }
}
