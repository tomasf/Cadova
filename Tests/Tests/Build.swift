import Foundation
import Testing
import ThreeMF
@testable import Cadova

struct BuildTests {
    init() {
        Platform.revealingFilesDisabled = true
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

    // MARK: - Metadata Tests

    /// Reads the metadata actually stored in a written 3MF, keyed by field.
    private func metadataFields(of url: URL) throws -> [ThreeMF.Metadata.Name: String] {
        let reader = try ThreeMF.PackageReader(url: url)
        return try reader.model().metadata.reduce(into: [:]) { $0[$1.name] = $1.value }
    }

    @Test func `Model metadata reaches the 3MF file`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            await Model("with-metadata") {
                Metadata(title: "Test Model", author: "Test Author", license: "MIT")
                Box(10)
            }
        }

        let fields = try metadataFields(of: tempDir.appending(path: "with-metadata.3mf"))
        #expect(fields[.title] == "Test Model")
        #expect(fields[.designer] == "Test Author")
        #expect(fields[.licenseTerms] == "MIT")
    }

    @Test func `Model metadata overrides Project metadata field by field`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            Metadata(title: "Project Title", author: "Project Author")

            await Model("model") {
                Metadata(title: "Model Title")
                Box(10)
            }
        }

        // Fields are merged individually rather than replaced wholesale: the model's title wins,
        // and the author it leaves unset is still inherited from the project.
        let fields = try metadataFields(of: tempDir.appending(path: "model.3mf"))
        #expect(fields[.title] == "Model Title")
        #expect(fields[.designer] == "Project Author")
    }

    @Test func `Group metadata applies to the models inside it`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await Project(root: tempDir) {
            Metadata(title: "Project Title", author: "Project Author")

            await Group("with-metadata") {
                Metadata(author: "Group Author")

                await Model("model") {
                    Box(10)
                }
            }
        }

        let fields = try metadataFields(of: tempDir.appending(path: "with-metadata/model.3mf"))
        #expect(fields[.designer] == "Group Author")
        #expect(fields[.title] == "Project Title")
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
                @Environment(\.segmentation) var segmentation
                capture.segmentation = segmentation
                Box(10)
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

                @Environment(\.segmentation) var segmentation
                capture.segmentation = segmentation
                Box(10)
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
                    @Environment(\.tolerance) var tolerance
                    capture.tolerance = tolerance
                    Box(10)
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

                    @Environment(\.tolerance) var tolerance
                    capture.tolerance = tolerance
                    Box(10)
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
                        @Environment(\.segmentation) var segmentation
                        @Environment(\.tolerance) var tolerance
                        capture.segmentation = segmentation
                        capture.tolerance = tolerance
                        Box(10)
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
