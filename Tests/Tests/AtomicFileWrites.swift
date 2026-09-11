import Foundation
import Testing
@testable import Cadova

/// A stand-in for a real output provider, so that the write path can be exercised without
/// building any geometry.
private struct StubDataProvider: OutputDataProvider {
    let data: Data
    var fileExtension: String { "bin" }

    func generateOutput(context: EvaluationContext) async throws -> Data { data }
}

private struct WriteInterrupted: Error {}

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
private let fileSizeLimitsAreAvailable = {
    #if os(Windows)
    false
    #else
    true
    #endif
}()

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

/// A model file is published by writing it beside its destination and moving it into place, so that
/// a write that fails partway through leaves the file that was already there exactly as it was.
/// `Data.write(to:)` truncates the destination the moment it opens it, so before this a full disk or
/// an interrupted process replaced a known-good export with a fragment.
struct AtomicFileWriteTests {
    @Test(.enabled(if: readOnlyDirectoriesAreEnforced))
    func `a read-only directory blocks even a rewrite of a file already in it`() async throws {
        // Publishing writes a temporary file beside the destination, so it needs the directory to be
        // writable even where the destination file itself is. `Data.write(to:)` needed only the file,
        // so this is a real narrowing, and the exchange is worth stating: what it buys is that the
        // existing file is still intact afterwards, which truncating in place could not promise.
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let destination = directory.appending(path: "model.bin")
        let originalData = Data(repeating: 0x41, count: 4096)
        try originalData.write(to: destination)

        await withReadOnlyDirectory(directory) {
            #expect(throws: (any Error).self) {
                try FileManager().publishFile(at: destination) { temporaryURL in
                    try Data(repeating: 0x42, count: 4096).write(to: temporaryURL)
                }
            }
        }

        #expect(try Data(contentsOf: destination) == originalData)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["model.bin"])
    }

    @Test func `an interrupted write leaves the previous file untouched`() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let destination = directory.appending(path: "model.bin")
        let originalData = Data(repeating: 0x41, count: 4096)
        try originalData.write(to: destination)

        #expect(throws: WriteInterrupted.self) {
            try FileManager().publishFile(at: destination) { temporaryURL in
                // A write that gets some of the way through and then dies, as a full disk or an
                // interrupted process would.
                try Data(repeating: 0x42, count: 2048).write(to: temporaryURL)
                throw WriteInterrupted()
            }
        }

        #expect(try Data(contentsOf: destination) == originalData)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["model.bin"])
    }

    /// Windows has no `getrlimit`, so there is no way to make a write fail partway through there.
    /// The direct `publishFile` test above covers the same guarantee without needing one.
    @Test(.enabled(if: fileSizeLimitsAreAvailable))
    func `an existing model file survives a write that fails partway through`() async throws {
        #if os(Windows)
        return
        #else
        // Run in a child process: the destination's own file system has to run out of room for the
        // real write path to fail mid-write, and the file size limit that arranges that is
        // process-wide.
        let result = await #expect(processExitsWith: .success, observing: [\.standardOutputContent]) {
            let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appending(path: "model.bin")

            // The known-good file that must still be there once the new write has failed.
            let originalData = Data(repeating: 0x41, count: 4096)
            try originalData.write(to: destination)

            // Cap the size of any file this process writes, so that a large write fails partway
            // through rather than at `open` time — the shape a full disk has.
            // `RLIMIT_FSIZE` is an `Int32` on Darwin and an enum on Glibc, so the resource has to
            // be spelled per platform even though the call is the same.
            #if canImport(Darwin)
            let fileSizeLimit = RLIMIT_FSIZE
            #else
            let fileSizeLimit = __rlimit_resource_t(RLIMIT_FSIZE.rawValue)
            #endif

            var limit = rlimit()
            guard getrlimit(fileSizeLimit, &limit) == 0 else {
                print("could not read RLIMIT_FSIZE")
                exit(EXIT_FAILURE)
            }
            limit.rlim_cur = 8192
            guard setrlimit(fileSizeLimit, &limit) == 0 else {
                print("could not lower RLIMIT_FSIZE")
                exit(EXIT_FAILURE)
            }
            signal(SIGXFSZ, SIG_IGN)

            let provider = StubDataProvider(data: Data(repeating: 0x42, count: 1 << 20))
            do {
                try await provider.writeOutput(to: destination, context: EvaluationContext())
                print("the write unexpectedly succeeded")
                exit(EXIT_FAILURE)
            } catch {
                print("the write failed, as it should: \(error)")
            }

            let survivingData = try Data(contentsOf: destination)
            print("destination now holds \(survivingData.count) bytes; it held \(originalData.count) before")
            if survivingData != originalData {
                print("THE PREVIOUS FILE WAS DESTROYED")
                exit(EXIT_FAILURE)
            }

            let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            print("directory contains: \(leftovers)")
            if leftovers != ["model.bin"] {
                print("A PARTIAL FILE WAS LEFT BEHIND")
                exit(EXIT_FAILURE)
            }
        }

        let output = String(decoding: try #require(result?.standardOutputContent), as: UTF8.self)
        #expect(output.contains("THE PREVIOUS FILE WAS DESTROYED") == false)
        #expect(output.contains("destination now holds 4096 bytes"))
        #endif
    }
}
