import Foundation
import Testing
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
