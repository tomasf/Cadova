import Foundation
import Testing
@testable import Cadova

private final class CapturedValue<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: T?

    var value: T? {
        get { lock.withLock { storedValue } }
        set { lock.withLock { storedValue = newValue } }
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}

struct EnvironmentDirectiveRerunTests {
    private let tempDir: URL

    init() throws {
        Platform.revealingFilesDisabled = true
        tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    @Test func `Environment reads in a model builder see the model's own directives`() async throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let capturedTolerance = CapturedValue<Double>()
        let volume = CapturedValue<Double>()

        await Model(tempDir.appending(path: "model").path) {
            Environment { $0.tolerance = 0.5 }

            @Environment(\.tolerance) var tolerance
            let _ = capturedTolerance.value = tolerance

            Box(1.0 + tolerance).measuring { geometry, measurements in
                let _ = volume.value = measurements.volume
                geometry
            }
        }

        #expect(capturedTolerance.value == 0.5)
        #expect(volume.value?.equals(1.5 * 1.5 * 1.5, within: 1e-6) == true)
    }

    @Test func `Model builders without environment directives run once`() async throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let runCount = Counter()

        await Model(tempDir.appending(path: "model").path) {
            let _ = runCount.increment()
            Box(1)
        }

        #expect(runCount.value == 1)
    }

    @Test func `Model builders with environment directives run twice`() async throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let runCount = Counter()

        await Model(tempDir.appending(path: "model").path) {
            Environment { $0.tolerance = 0.5 }
            let _ = runCount.increment()
            Box(1)
        }

        #expect(runCount.value == 2)
    }

    @Test func `Environment directives are taken from the first run`() async throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let capturedTolerance = CapturedValue<Double>()

        // The directive is conditional on a read of the very value it sets, so it disappears
        // in the second run. The environment must still reflect the first run's directives.
        await Model(tempDir.appending(path: "model").path) {
            @Environment(\.tolerance) var tolerance
            if tolerance < 0.25 {
                Environment { $0.tolerance = 0.5 }
            }
            let _ = capturedTolerance.value = tolerance
            Box(1)
        }

        #expect(capturedTolerance.value == 0.5)
    }

    // Project and Group builders don't produce geometry themselves, so they are not re-run;
    // their directives apply to the models within, but reads directly in the project or group
    // builder body see only the inherited environment.

    @Test func `Project directives apply to model builders but not to the project builder itself`() async throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let projectRead = CapturedValue<Double>()
        let modelRead = CapturedValue<Double>()
        let projectRunCount = Counter()

        await Project(root: tempDir) {
            Environment { $0.tolerance = 0.5 }

            @Environment(\.tolerance) var tolerance
            let _ = projectRead.value = tolerance
            let _ = projectRunCount.increment()

            await Model("model") {
                @Environment(\.tolerance) var tolerance
                let _ = modelRead.value = tolerance
                Box(1)
            }
        }

        #expect(projectRead.value == 0)
        #expect(projectRunCount.value == 1)
        #expect(modelRead.value == 0.5)
        #expect(FileManager.default.fileExists(atPath: tempDir.appending(path: "model.3mf").path))
    }

    @Test func `Group directives apply to model builders but not to the group builder itself`() async throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let groupRead = CapturedValue<Double>()
        let modelRead = CapturedValue<Double>()

        await Project(root: tempDir) {
            await Group("sub") {
                Environment { $0.tolerance = 0.25 }

                @Environment(\.tolerance) var tolerance
                let _ = groupRead.value = tolerance

                await Model("model") {
                    @Environment(\.tolerance) var tolerance
                    let _ = modelRead.value = tolerance
                    Box(1)
                }
            }
        }

        #expect(groupRead.value == 0)
        #expect(modelRead.value == 0.25)
        #expect(FileManager.default.fileExists(atPath: tempDir.appending(path: "sub/model.3mf").path))
    }

    @Test func `Model directives override inherited project directives for builder reads`() async throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let capturedTolerance = CapturedValue<Double>()

        await Project(root: tempDir) {
            Environment { $0.tolerance = 0.25 }

            await Model("model") {
                Environment { $0.tolerance = 0.75 }

                @Environment(\.tolerance) var tolerance
                let _ = capturedTolerance.value = tolerance

                Box(1)
            }
        }

        #expect(capturedTolerance.value == 0.75)
    }

    @Test func `Environment reads in ModelFileGenerator builders see their own directives`() async throws {
        let capturedTolerance = CapturedValue<Double>()

        _ = try await ModelFileGenerator().build(named: "model") {
            Environment { $0.tolerance = 0.5 }

            @Environment(\.tolerance) var tolerance
            let _ = capturedTolerance.value = tolerance

            Box(1)
        }

        #expect(capturedTolerance.value == 0.5)
    }
}
