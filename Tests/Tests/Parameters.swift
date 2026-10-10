import Foundation
import Testing
@testable import Cadova

private enum Finish: String, CaseIterable, ParameterValue {
    case matte, glossy
}

private final class CapturedValue<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: T?

    var value: T? {
        get { lock.withLock { storedValue } }
        set { lock.withLock { storedValue = newValue } }
    }
}

private struct ParametricBox: Geometry3D {
    @Parameter("size") var size = 1.0

    var body: any Geometry3D {
        Box(size)
    }
}

struct ParameterTests {
    @Test func `Parameter values parse from strings`() {
        #expect(Int(parameterString: "42") == 42)
        #expect(Int(parameterString: "4.5") == nil)
        #expect(Double(parameterString: "1.5") == 1.5)
        #expect(Double(parameterString: "abc") == nil)
        #expect(String(parameterString: "hello") == "hello")
        #expect(Bool(parameterString: "true") == true)
        #expect(Bool(parameterString: "NO") == false)
        #expect(Bool(parameterString: "2") == nil)
        #expect(Angle(parameterString: "45") == 45°)
        #expect(Angle(parameterString: "45°") == 45°)
        #expect(Angle(parameterString: "45deg") == 45°)
        #expect(Angle(parameterString: "0.5rad") == Angle(radians: 0.5))
        #expect(Angle(parameterString: "1.5x") == nil)
        #expect(Finish(parameterString: "glossy") == .glossy)
        #expect(Finish(parameterString: "sparkly") == nil)
    }

    @Test func `Command line param arguments are parsed`() {
        let args = CommandLineArguments(arguments: [
            "exe", "--param", "count=5", "--param=wall=1.6", "--param", "malformed", "--param", "text=a=b"
        ])
        #expect(args.parameters == ["count": "5", "wall": "1.6", "text": "a=b"])
    }

    @Test func `Parameter returns its default when unset`() {
        EnvironmentValues.defaultEnvironment.whileCurrent {
            @Parameter("count") var count = 3
            #expect(count == 3)
            #expect($count.isOverridden == false)
        }
    }

    @Test func `Parameter reads typed values from the environment`() {
        let environment = EnvironmentValues.defaultEnvironment
            .settingParameter("count", to: 7)
            .settingParameter("finish", to: Finish.glossy)

        environment.whileCurrent {
            @Parameter("count") var count = 3
            @Parameter("finish") var finish = Finish.matte
            #expect(count == 7)
            #expect(finish == .glossy)
            #expect($count.isOverridden == true)
        }
    }

    @Test func `Raw parameters are parsed as the reader's type`() {
        let environment = EnvironmentValues.defaultEnvironment
            .settingRawParameters(["count": "7", "invalid": "xyz"])

        environment.whileCurrent {
            @Parameter("count") var count = 3
            @Parameter("invalid") var invalid = 4
            #expect(count == 7)
            #expect(invalid == 4) // Unparsable value falls back to the default
            #expect($invalid.isOverridden == false)
        }
    }

    @Test func `Type mismatches for typed values fall back to the default`() {
        let environment = EnvironmentValues.defaultEnvironment.settingParameter("count", to: "seven")

        environment.whileCurrent {
            @Parameter("count") var count = 3
            #expect(count == 3)
        }
    }

    @Test func `Removing a parameter restores the default`() {
        let environment = EnvironmentValues.defaultEnvironment
            .settingParameter("count", to: 7)
            .settingParameter("count", to: Int?.none)

        environment.whileCurrent {
            @Parameter("count") var count = 3
            #expect(count == 3)
        }
    }

    @Test func `withParameter overrides a parameter for a subtree`() async throws {
        let defaultVolume = try await ParametricBox().measurements.volume
        #expect(defaultVolume.equals(1, within: 1e-6))

        let overriddenVolume = try await ParametricBox().withParameter("size", 5.0).measurements.volume
        #expect(overriddenVolume.equals(125, within: 1e-6))
    }

    @Test func `Command line parameters reach standalone models`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let builderValue = CapturedValue<Double>()
        let bodyVolume = CapturedValue<Double>()

        await CommandLineArguments.$overriddenArguments.withValue(["exe", "--param", "size=5"]) {
            await Model(tempDir.appending(path: "model").path) {
                @Parameter("size") var size = 1.0
                let _ = builderValue.value = size

                ParametricBox().measuring { geometry, measurements in
                    let _ = bodyVolume.value = await measurements.volume
                    geometry
                }
            }
        }

        #expect(builderValue.value == 5)
        #expect(bodyVolume.value?.equals(125, within: 1e-6) == true)
    }

    @Test func `Command line parameters reach models in a project`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let capturedSize = CapturedValue<Double>()

        await CommandLineArguments.$overriddenArguments.withValue(["exe", "--param", "size=2.5"]) {
            await Project(root: tempDir) {
                await Model("model") {
                    @Parameter("size") var size = 1.0
                    let _ = capturedSize.value = size
                    Box(size)
                }
            }
        }

        #expect(capturedSize.value == 2.5)
    }

    @Test func `Environment directives take precedence over command line parameters`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let volume = CapturedValue<Double>()

        await CommandLineArguments.$overriddenArguments.withValue(["exe", "--param", "size=5"]) {
            await Model(tempDir.appending(path: "model").path) {
                Environment { $0.setParameter("size", to: 2.0) }

                ParametricBox().measuring { geometry, measurements in
                    let _ = volume.value = await measurements.volume
                    geometry
                }
            }
        }

        #expect(volume.value?.equals(8, within: 1e-6) == true)
    }

    @Test func `Subtree overrides take precedence over command line parameters`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let volume = CapturedValue<Double>()

        await CommandLineArguments.$overriddenArguments.withValue(["exe", "--param", "size=5"]) {
            await Model(tempDir.appending(path: "model").path) {
                ParametricBox()
                    .withParameter("size", 2.0)
                    .measuring { geometry, measurements in
                        let _ = volume.value = await measurements.volume
                        geometry
                    }
            }
        }

        #expect(volume.value?.equals(8, within: 1e-6) == true)
    }

    @Test func `Listing and output arguments are parsed`() {
        let args = CommandLineArguments(arguments: ["exe", "--list-parameters", "--output", "/tmp/out"])
        #expect(args.listsParameters == true)
        #expect(args.outputDirectory == "/tmp/out")
        #expect(CommandLineArguments(arguments: ["exe", "--output=/x"]).outputDirectory == "/x")
        #expect(CommandLineArguments(arguments: ["exe"]).listsParameters == false)

        let toFile = CommandLineArguments(arguments: ["exe", "--list-parameters=/tmp/parameters.json"])
        #expect(toFile.listsParameters == true)
        #expect(toFile.parameterListPath == "/tmp/parameters.json")
        #expect(args.parameterListPath == nil)
    }

    @Test func `Parameters describe their kind and metadata`() {
        @Parameter("height", in: 10...50, step: 0.5, description: "Plate height") var height = 20.0
        @Parameter("finish") var finish = Finish.matte
        @Parameter("tilt") var tilt = 15°

        #expect($height.descriptor == ParameterDescriptor(
            name: "height", kind: .number, defaultValue: "20.0",
            minimum: "10.0", maximum: "50.0", step: "0.5", description: "Plate height"
        ))
        #expect($finish.descriptor.kind == .choice(["matte", "glossy"]))
        #expect($finish.descriptor.defaultValue == "matte")
        #expect($tilt.descriptor.kind == .angle)
        #expect(Angle(parameterString: $tilt.descriptor.defaultValue) == 15°)
    }

    @Test func `Catalog collects parameters from every model without writing files`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        struct Plate: Geometry3D {
            @Parameter("width", in: 10...100) var width = 40.0
            @Parameter("rounded") var rounded = false
            @Parameter("radius") var radius = 3.0 // Only read when rounded is true

            var body: any Geometry3D {
                if rounded {
                    Box(x: width, y: width, z: radius)
                } else {
                    Box(x: width, y: width, z: 2)
                }
            }
        }

        let catalog = await ParameterCatalog.collect(options: []) {
            await Model(tempDir.appending(path: "plate").path) {
                Plate()
            }
            await Group("parts") {
                await Model("peg") {
                    Metadata(title: "Peg", description: "A peg with a configurable size")
                    @Parameter("count", in: 1...8) var count = 3
                    @Parameter("finish") var finish = Finish.glossy
                    Box(Double(count))
                }
            }
        }

        let json = try JSONSerialization.jsonObject(with: catalog.jsonData()) as? [String: Any]
        let models = try #require(json?["models"] as? [[String: Any]])
        let parameters = Dictionary(uniqueKeysWithValues: models.map {
            ($0["name"] as? String ?? "", ($0["parameters"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String })
        })
        #expect(parameters["parts/peg"] == ["count", "finish"])
        #expect(parameters[tempDir.appending(path: "plate").path] == ["width", "rounded", "radius"])

        let peg = try #require(models.first { $0["name"] as? String == "parts/peg" })
        #expect(peg["title"] as? String == "Peg")
        #expect(peg["description"] as? String == "A peg with a configurable size")
        #expect(models.first { $0["name"] as? String != "parts/peg" }?["title"] == nil)
        let count = try #require((peg["parameters"] as? [[String: Any]])?.first)
        #expect(count["type"] as? String == "integer")
        #expect(count["default"] as? Int == 3)
        #expect(count["minimum"] as? Int == 1)
        #expect(count["maximum"] as? Int == 8)

        let written = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(written.isEmpty)
        #expect(FileManager.default.fileExists(atPath: "parts") == false)
    }

    @Test func `Output argument replaces the project's output directory`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let projectDir = tempDir.appending(path: "project")
        let outputDir = tempDir.appending(path: "output")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        await CommandLineArguments.$overriddenArguments.withValue(["exe", "--output", outputDir.path]) {
            await Project(root: projectDir) {
                await Model("cube", options: .format3D(.stl)) {
                    Box(2)
                }
            }
        }

        #expect(FileManager.default.fileExists(atPath: outputDir.appending(path: "cube.stl").path))
        #expect(FileManager.default.fileExists(atPath: projectDir.path) == false)
    }

    @Test func `Listing parameters to a file writes JSON and builds nothing`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let listURL = tempDir.appending(path: "parameters.json")

        await CommandLineArguments.$overriddenArguments.withValue(["exe", "--list-parameters=\(listURL.path)"]) {
            await Project(root: tempDir) {
                await Model("box", options: .format3D(.stl)) {
                    Metadata(title: "Box")
                    ParametricBox()
                }
            }
        }

        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: listURL)) as? [String: Any]
        let model = try #require((json?["models"] as? [[String: Any]])?.first)
        #expect(model["name"] as? String == "box")
        #expect(model["title"] as? String == "Box")
        #expect((model["parameters"] as? [[String: Any]])?.first?["name"] as? String == "size")
        #expect(try FileManager.default.contentsOfDirectory(atPath: tempDir.path) == ["parameters.json"])
    }
}
