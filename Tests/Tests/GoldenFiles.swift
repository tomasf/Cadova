import Foundation
import Testing
@testable import Cadova

struct GoldenFileTests {
    /// A golden record nothing compares against is worse than no golden record: it looks like coverage,
    /// it survives schema changes nobody applies to it, and it goes on being shipped in the test bundle
    /// long after the test that wrote it is gone. `golden/helix.json` sat here in an obsolete schema
    /// while `sweptAlongHelix` had no test at all.
    @Test func `every golden file is referenced by a test`() async throws {
        let testRoot = URL(filePath: #filePath).deletingLastPathComponent()
        let goldenRoot = testRoot.appending(path: "golden")

        let onDisk = try FileManager.default
            .subpathsOfDirectory(atPath: goldenRoot.path(percentEncoded: false))
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(".json".count)) }

        // Escaped quotes so this pattern doesn't match itself when the scan reaches this very file.
        let reference = try Regex("goldenFile: \"([^\"]+)\"")
        let referenced = try Set(
            FileManager.default.subpathsOfDirectory(atPath: testRoot.path(percentEncoded: false))
                .filter { $0.hasSuffix(".swift") }
                .flatMap { path -> [String] in
                    let source = try String(contentsOf: testRoot.appending(path: path), encoding: .utf8)
                    return source.matches(of: reference).map { String($0[1].substring ?? "") }
                }
        )

        let orphans = onDisk.filter { referenced.contains($0) == false }.sorted()
        #expect(orphans.isEmpty, "Golden files no test refers to: \(orphans.joined(separator: ", "))")
    }
}
