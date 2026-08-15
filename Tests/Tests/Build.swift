import Foundation
import Testing
@_spi(ArchiveFinalizer)
@testable import Cadova

private struct TagAccumulator: ResultElement {
    var values: [String]
    init() { values = [] }
    init(combining elements: [TagAccumulator]) { values = elements.flatMap(\.values) }
}

struct BuildTests {
    init() {
        Settings.isFileRevealingEnabled = false
    }

    // MARK: - Model Tests

    @Test func `Model creates file with correct extension for 3D geometry`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            await Model("test-box") {
                Box(10)
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(files.contains("test-box.3mf"))
    }

    @Test func `Model creates file with correct extension for 2D geometry with SVG format`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir, options: .format2D(.svg)) {
            await Model("test-circle") {
                Circle(diameter: 10)
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(files.contains("test-circle.svg"))
    }

    @Test func `Model creates 3mf for 2D geometry by default`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            await Model("test-2d") {
                Circle(diameter: 10)
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(files.contains("test-2d.3mf"))
    }

    @Test func `Model with STL format creates stl file`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir, options: .format3D(.stl)) {
            await Model("test-stl") {
                Box(10)
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(files.contains("test-stl.stl"))
    }

    @Test func `Model accepts metadata`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            await Model("with-metadata") {
                Metadata(title: "Test Model", author: "Test Author")
                Box(10)
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(files.contains("with-metadata.3mf"))
    }

    @Test func `withArchiveFinalizer handler runs with a resolvable object id and can add a file`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let part = Part("box", semantic: .solid)

        await confirmation("archive finalizer runs") { confirm in
            await Project(root: tempDir) {
                await Model("finalized") {
                    Box(10)
                        .inPart(part)
                        .withArchiveFinalizer { archive in
                            #expect(archive.objectID(for: part) != nil)
                            #expect(archive.parts == [part])
                            try archive.addFile(at: "Metadata/test.config", data: Data("hello".utf8))
                            confirm()
                        }
                }
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(files.contains("finalized.3mf"))
    }

    @Test func `withArchiveFinalizer's addFile accepts a content type and relationship type`() async throws {
        // Content-type/relationship registration correctness itself is covered at the ThreeMF package
        // level (where Nodal is available to parse [Content_Types].xml directly); this just confirms
        // ModelArchive actually plumbs the parameters through rather than silently dropping them.
        let data = try await ModelFileGenerator.build {
            Box(10)
                .withArchiveFinalizer { archive in
                    try archive.addFile(
                        at: "Metadata/custom.xml",
                        contentType: "application/vnd.example+xml",
                        relationshipType: "http://example.com/relationships/custom",
                        data: Data("<custom/>".utf8)
                    )
                }
        }.data()

        // Filenames are stored uncompressed in a zip's local headers, so this substring check reliably
        // confirms the file was added even though its content is compressed.
        #expect(data.range(of: Data("Metadata/custom.xml".utf8)) != nil)
    }

    @Test func `withArchiveFinalizer handlers can measure the root geometry`() async throws {
        let data = try await ModelFileGenerator.build {
            Box(x: 10, y: 20, z: 5)
                .adding {
                    Box(x: 10, y: 20, z: 5)
                        .translated(x: 30)
                        .inPart(Part("second", semantic: .solid))
                }
                .withArchiveFinalizer { archive in
                    let bounds = await archive.evaluator.bounds(of: archive.rootGeometry, scope: .allParts)
                    #expect(bounds?.size ?? .zero ≈ Vector3D(40, 20, 5))
                    try archive.addFile(at: "Metadata/size.txt", data: Data("\(bounds?.size ?? .zero)".utf8))
                }
        }.data()

        #expect(data.range(of: Data("Metadata/size.txt".utf8)) != nil)
    }

    @Test func `withArchiveFinalizer does not rerun when the same geometry value is reused in a tree`() async throws {
        // A geometry value that already carries a finalizer, reused at two points in the same tree
        // (not two separate calls to withArchiveFinalizer), must not run the finalizer twice — the
        // id is generated once per call, and value semantics mean both copies carry it along.
        await confirmation("finalizer runs", expectedCount: 1) { confirm in
            let taggedBox = Box(10).withArchiveFinalizer { _ in confirm() }
            _ = try? await ModelFileGenerator.build {
                taggedBox
                    .adding {
                        taggedBox.translated(x: 20)
                    }
            }.data()
        }
    }

    @Test func `withArchiveFinalizer handlers can read tree-wide result elements and dedupe file writes`() async throws {
        // Simulates a consumer (like Fabricate) that attaches a finalizer redundantly from several
        // places in a tree, each needing to see data contributed by *all* of them, but where only
        // one of them should actually write the combined file — a second write to the same path
        // throws, even with identical content, unless the finalizer checks `fileExists` first.
        let writeCombinedFile: @Sendable (ModelArchive) throws -> Void = { archive in
            guard !archive.fileExists(at: "Metadata/combined.txt") else { return }
            let values = archive.resultElement(TagAccumulator.self).values.sorted()
            try archive.addFile(at: "Metadata/combined.txt", data: Data(values.joined(separator: ",").utf8))
        }

        // If dedup didn't work, the second finalizer's addFile would throw ZipError.duplicateFileEntry
        // here, failing the test.
        let data = try await ModelFileGenerator.build {
            Box(10)
                .modifyingResult(TagAccumulator.self) { $0.values.append("a") }
                .withArchiveFinalizer(writeCombinedFile)
                .adding {
                    Box(5)
                        .modifyingResult(TagAccumulator.self) { $0.values.append("b") }
                        .withArchiveFinalizer(writeCombinedFile)
                }
        }.data()

        #expect(data.range(of: Data("Metadata/combined.txt".utf8)) != nil)
    }

    @Test func `Model accepts environment directives`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            await Model("with-environment") {
                Environment(\.segmentation, .fixed(8))
                Cylinder(diameter: 10, height: 10)
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(files.contains("with-environment.3mf"))
    }

    @Test func `Model with no geometry produces no file`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            await Model("empty-model") {
                // No geometry
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(files.isEmpty)
    }

    // MARK: - Group Tests

    @Test func `Group creates subdirectory`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            await Group("parts") {
                await Model("box") {
                    Box(10)
                }
            }
        }

        let partsDir = tempDir.appending(path: "parts")
        #expect(FileManager.default.fileExists(atPath: partsDir.path))

        let files = try FileManager.default.contentsOfDirectory(atPath: partsDir.path)
        #expect(files.contains("box.3mf"))
    }

    @Test func `Group without name does not create subdirectory`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            await Group {
                await Model("ungrouped") {
                    Box(10)
                }
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(files.contains("ungrouped.3mf"))
    }

    @Test func `Nested groups create nested directories`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            await Group("outer") {
                await Group("inner") {
                    await Model("nested") {
                        Box(10)
                    }
                }
            }
        }

        let nestedDir = tempDir.appending(path: "outer/inner")
        #expect(FileManager.default.fileExists(atPath: nestedDir.path))

        let files = try FileManager.default.contentsOfDirectory(atPath: nestedDir.path)
        #expect(files.contains("nested.3mf"))
    }

    @Test func `Group inherits options from Project`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir, options: .format3D(.stl)) {
            await Group("stl-parts") {
                await Model("inherited-format") {
                    Box(10)
                }
            }
        }

        let groupDir = tempDir.appending(path: "stl-parts")
        let files = try FileManager.default.contentsOfDirectory(atPath: groupDir.path)
        #expect(files.contains("inherited-format.stl"))
    }

    @Test func `Group accepts environment directives`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            await Group("with-env") {
                Environment(\.segmentation, .fixed(8))

                await Model("model") {
                    Cylinder(diameter: 10, height: 10)
                }
            }
        }

        let groupDir = tempDir.appending(path: "with-env")
        let files = try FileManager.default.contentsOfDirectory(atPath: groupDir.path)
        #expect(files.contains("model.3mf"))
    }

    @Test func `Group accepts metadata directives`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            await Group("with-metadata") {
                Metadata(author: "Group Author")

                await Model("model") {
                    Box(10)
                }
            }
        }

        let groupDir = tempDir.appending(path: "with-metadata")
        let files = try FileManager.default.contentsOfDirectory(atPath: groupDir.path)
        #expect(files.contains("model.3mf"))
    }

    @Test func `Model filter matches root model name without matching grouped model with same name`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir, options: ModelOptions(ModelFilter(names: ["Differential"]))) {
            await Model("Differential") {
                Box(10)
            }

            await Group("GroupName") {
                await Model("Differential") {
                    Sphere(diameter: 10)
                }
            }
        }

        #expect(FileManager.default.fileExists(atPath: tempDir.appending(path: "Differential.3mf").path))
        #expect(!FileManager.default.fileExists(atPath: tempDir.appending(path: "GroupName/Differential.3mf").path))
    }

    @Test func `Model filter matches grouped model by output relative path`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir, options: ModelOptions(ModelFilter(names: ["GroupName/Differential"]))) {
            await Model("Differential") {
                Box(10)
            }

            await Group("GroupName") {
                await Model("Differential") {
                    Sphere(diameter: 10)
                }
            }
        }

        #expect(!FileManager.default.fileExists(atPath: tempDir.appending(path: "Differential.3mf").path))
        #expect(FileManager.default.fileExists(atPath: tempDir.appending(path: "GroupName/Differential.3mf").path))
    }

    // MARK: - Project Tests

    @Test func `Project creates root directory`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            await Model("project-model") {
                Box(10)
            }
        }

        #expect(FileManager.default.fileExists(atPath: tempDir.path))
        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(files.contains("project-model.3mf"))
    }

    @Test func `Project accepts multiple models`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            await Model("model1") {
                Box(10)
            }
            await Model("model2") {
                Sphere(diameter: 10)
            }
            await Model("model3") {
                Cylinder(diameter: 5, height: 10)
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(files.contains("model1.3mf"))
        #expect(files.contains("model2.3mf"))
        #expect(files.contains("model3.3mf"))
    }

    @Test func `Project accepts environment directives`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            Environment(\.segmentation, .fixed(8))

            await Model("env-model") {
                Cylinder(diameter: 10, height: 10)
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(files.contains("env-model.3mf"))
    }

    @Test func `Project accepts metadata directives`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            Metadata(title: "Project Title", author: "Project Author")

            await Model("metadata-model") {
                Box(10)
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(files.contains("metadata-model.3mf"))
    }

    @Test func `Project with mixed models and groups`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            await Model("top-level") {
                Box(10)
            }

            await Group("subdir") {
                await Model("grouped") {
                    Sphere(diameter: 10)
                }
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(files.contains("top-level.3mf"))
        #expect(files.contains("subdir"))

        let subFiles = try FileManager.default.contentsOfDirectory(atPath: tempDir.appending(path: "subdir").path)
        #expect(subFiles.contains("grouped.3mf"))
    }

    @Test func `Project with nil root uses current directory`() async throws {
        // This test just verifies the API compiles and runs without crashing
        // We don't actually create files since we don't want to pollute the working directory
        await Project(root: nil as URL?) {
            // Empty project - no files created
        }
    }

    @Test func `Project with string path`() async throws {
        let tempPath = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: tempPath) }

        await Project(root: tempPath) {
            await Model("string-path-model") {
                Box(10)
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: tempPath)
        #expect(files.contains("string-path-model.3mf"))
    }

    // MARK: - Environment Inheritance Tests

    @Test func `Model inherits environment from Project`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Project sets environment, model should inherit it
        await Project(root: tempDir) {
            Environment(\.segmentation, .fixed(6))

            await Model("inherited-env") {
                Cylinder(diameter: 10, height: 10)
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(files.contains("inherited-env.3mf"))
    }

    @Test func `Model can override environment from Project`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            Environment(\.segmentation, .fixed(6))

            await Model("overridden-env") {
                Environment(\.segmentation, .fixed(12))
                Cylinder(diameter: 10, height: 10)
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(files.contains("overridden-env.3mf"))
    }

    @Test func `Group inherits environment from Project`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            Environment(\.segmentation, .fixed(6))

            await Group("inherited") {
                await Model("model") {
                    Cylinder(diameter: 10, height: 10)
                }
            }
        }

        let groupDir = tempDir.appending(path: "inherited")
        let files = try FileManager.default.contentsOfDirectory(atPath: groupDir.path)
        #expect(files.contains("model.3mf"))
    }

    @Test func `Model inherits environment through Group`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            Environment(\.segmentation, .fixed(6))

            await Group("group") {
                Environment(\.tolerance, 0.1)

                await Model("model") {
                    Cylinder(diameter: 10, height: 10)
                }
            }
        }

        let groupDir = tempDir.appending(path: "group")
        let files = try FileManager.default.contentsOfDirectory(atPath: groupDir.path)
        #expect(files.contains("model.3mf"))
    }

    // MARK: - Environment Value Verification Tests

    @Test func `Project environment is applied to Model geometry`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let capture = EnvironmentCapture()

        await Project(root: tempDir) {
            Environment(\.segmentation, .fixed(42))

            await Model("test") {
                readEnvironment { env in
                    capture.segmentation = env.segmentation
                    return Box(10)
                }
            }
        }

        #expect(capture.segmentation == .fixed(42))
    }

    @Test func `Model environment overrides Project environment`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let capture = EnvironmentCapture()

        await Project(root: tempDir) {
            Environment(\.segmentation, .fixed(10))

            await Model("test") {
                Environment(\.segmentation, .fixed(99))

                readEnvironment { env in
                    capture.segmentation = env.segmentation
                    return Box(10)
                }
            }
        }

        #expect(capture.segmentation == .fixed(99))
    }

    @Test func `Group environment overrides Project environment`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let capture = EnvironmentCapture()

        await Project(root: tempDir) {
            Environment(\.tolerance, 0.5)

            await Group("group") {
                Environment(\.tolerance, 0.1)

                await Model("test") {
                    readEnvironment { env in
                        capture.tolerance = env.tolerance
                        return Box(10)
                    }
                }
            }
        }

        #expect(capture.tolerance == 0.1)
    }

    @Test func `Model environment overrides Group environment`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let capture = EnvironmentCapture()

        await Project(root: tempDir) {
            Environment(\.tolerance, 1.0)

            await Group("group") {
                Environment(\.tolerance, 0.5)

                await Model("test") {
                    Environment(\.tolerance, 0.01)

                    readEnvironment { env in
                        capture.tolerance = env.tolerance
                        return Box(10)
                    }
                }
            }
        }

        #expect(capture.tolerance == 0.01)
    }

    @Test func `Nested Group environments stack correctly`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let capture = EnvironmentCapture()

        await Project(root: tempDir) {
            Environment(\.segmentation, .fixed(10))
            Environment(\.tolerance, 1.0)

            await Group("outer") {
                Environment(\.tolerance, 0.5)  // Override tolerance, keep segmentation

                await Group("inner") {
                    Environment(\.segmentation, .fixed(20))  // Override segmentation, keep tolerance

                    await Model("test") {
                        readEnvironment { env in
                            capture.segmentation = env.segmentation
                            capture.tolerance = env.tolerance
                            return Box(10)
                        }
                    }
                }
            }
        }

        #expect(capture.segmentation == .fixed(20))
        #expect(capture.tolerance == 0.5)
    }
}

private final class EnvironmentCapture: @unchecked Sendable {
    var segmentation: Segmentation?
    var tolerance: Double?
}

/// Minimal box for carrying a value out of a finalizer closure.
private final class Captured<T>: @unchecked Sendable {
    var value: T?
}

struct ArchiveContentsTests {
    @Test func `a finalizer can read the model file it is about to seal`() async throws {
        // The read has to reach the model files, not just what a finalizer added itself — that's what
        // makes it possible to take the generated model apart and put it back together differently.
        let seen = Captured<String>()
        _ = try await ModelFileGenerator.build {
            Box(10)
                .inPart(Part("A", semantic: .solid))
                .adding { Box(5).translated(x: 20).inPart(Part("B", semantic: .solid)) }
                .withArchiveFinalizer { archive in
                    seen.value = archive.contents(at: "3D/3dmodel.model")
                        .map { String(decoding: $0, as: UTF8.self) }
                }
        }.data()

        let model = try #require(seen.value)
        #expect(model.contains("<build"))
        #expect(model.contains("objectid="))
    }

    @Test func `a model file written back stays written back`() async throws {
        // Reading a model file stages it, and writing over it has to stick — otherwise the archive
        // would regenerate the model over the top when it seals and quietly discard the edit. Checked
        // by reading it again rather than by unpacking, which needs no zip reader here.
        let marker = "<!--edited-->"
        let readBack = Captured<Bool>()
        _ = try await ModelFileGenerator.build {
            Box(10)
                .inPart(Part("A", semantic: .solid))
                .withArchiveFinalizer { archive in
                    guard let original = archive.contents(at: "3D/3dmodel.model") else { return }
                    try archive.addFile(at: "3D/3dmodel.model", data: original + Data(marker.utf8))
                    readBack.value = archive.contents(at: "3D/3dmodel.model")
                        .map { String(decoding: $0, as: UTF8.self).hasSuffix(marker) }
                }
        }.data()

        #expect(readBack.value == true)
    }

    @Test func `reading a path nothing was written to gives nothing`() async throws {
        let seen = Captured<Bool>()
        _ = try await ModelFileGenerator.build {
            Box(10).withArchiveFinalizer { archive in
                seen.value = archive.contents(at: "Metadata/nothing-here.config") == nil
            }
        }.data()
        #expect(seen.value == true)
    }
}
