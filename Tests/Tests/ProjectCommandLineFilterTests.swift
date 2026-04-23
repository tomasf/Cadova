import Foundation
import Testing
@testable import Cadova

struct ProjectCommandLineFilterTests {
    init() {
        Platform.revealingFilesDisabled = true
    }

    @Test func `Project applies model filter from --model command line argument`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await CommandLineArguments.$overriddenArguments.withValue(["CadovaTests", "--model", "Differential"]) {
            await Project(root: tempDir) {
                await Model("Differential") {
                    Box(10)
                }

                await Model("Other") {
                    Sphere(diameter: 10)
                }
            }
        }

        #expect(FileManager.default.fileExists(atPath: tempDir.appending(path: "Differential.3mf").path))
        #expect(!FileManager.default.fileExists(atPath: tempDir.appending(path: "Other.3mf").path))
    }

    @Test func `Project applies repeated --model=value command line arguments`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await CommandLineArguments.$overriddenArguments.withValue([
            "CadovaTests",
            "--model=Standalone",
            "--model=GroupName/Differential"
        ]) {
            await Project(root: tempDir) {
                await Model("Standalone") {
                    Box(10)
                }

                await Model("Ignored") {
                    Sphere(diameter: 10)
                }

                await Group("GroupName") {
                    await Model("Differential") {
                        Cylinder(diameter: 5, height: 10)
                    }

                    await Model("Other") {
                        Circle(diameter: 10)
                    }
                }
            }
        }

        #expect(FileManager.default.fileExists(atPath: tempDir.appending(path: "Standalone.3mf").path))
        #expect(!FileManager.default.fileExists(atPath: tempDir.appending(path: "Ignored.3mf").path))
        #expect(FileManager.default.fileExists(atPath: tempDir.appending(path: "GroupName/Differential.3mf").path))
        #expect(!FileManager.default.fileExists(atPath: tempDir.appending(path: "GroupName/Other.3mf").path))
    }

    @Test func `Project applies mixed --model NAME and --model=NAME command line arguments`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await CommandLineArguments.$overriddenArguments.withValue([
            "CadovaTests",
            "--model", "Standalone",
            "--model=GroupName/Differential"
        ]) {
            await Project(root: tempDir) {
                await Model("Standalone") {
                    Box(10)
                }

                await Model("Ignored") {
                    Sphere(diameter: 10)
                }

                await Group("GroupName") {
                    await Model("Differential") {
                        Cylinder(diameter: 5, height: 10)
                    }

                    await Model("Other") {
                        Circle(diameter: 10)
                    }
                }
            }
        }

        #expect(FileManager.default.fileExists(atPath: tempDir.appending(path: "Standalone.3mf").path))
        #expect(!FileManager.default.fileExists(atPath: tempDir.appending(path: "Ignored.3mf").path))
        #expect(FileManager.default.fileExists(atPath: tempDir.appending(path: "GroupName/Differential.3mf").path))
        #expect(!FileManager.default.fileExists(atPath: tempDir.appending(path: "GroupName/Other.3mf").path))
    }
}
