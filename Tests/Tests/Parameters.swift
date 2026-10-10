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
    @Parameter("Size") var size = 1.0

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

    @Test func `Parameter has its default value unless a customizer chooses one`() {
        EnvironmentValues.defaultEnvironment.whileCurrent {
            @Parameter("Count") var count = 3
            #expect(count == 3)
        }
    }

    @Test func `Chosen values are parsed as each parameter's type`() {
        var environment = EnvironmentValues.defaultEnvironment
        environment.parameterValues = ["Count": "7", "Finish": "glossy", "Invalid": "xyz"]

        environment.whileCurrent {
            @Parameter("Count") var count = 3
            @Parameter("Finish") var finish = Finish.matte
            @Parameter("Invalid") var invalid = 4
            #expect(count == 7)
            #expect(finish == .glossy)
            #expect(invalid == 4) // A value that doesn't parse leaves the default
        }
    }

    @Test func `Customizer requests are read from JSON`() throws {
        let json = #"{"model": "plate", "values": {"Width": "80"}, "output": "/out"}"#
        let request = try JSONDecoder().decode(CustomizerRequest.self, from: Data(json.utf8))
        #expect(request.model == "plate")
        #expect(request.values == ["Width": "80"])
        #expect(request.outputDirectory == "/out")
        #expect(request.parameterListPath == nil)

        let listing = try JSONDecoder().decode(CustomizerRequest.self, from: Data(#"{"listParameters": "/out/p.json"}"#.utf8))
        #expect(listing.parameterListPath == "/out/p.json")
        #expect(listing.values.isEmpty)
    }

    @Test func `Chosen values reach standalone models`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let builderValue = CapturedValue<Double>()
        let bodyVolume = CapturedValue<Double>()

        await CustomizerRequest.$overridden.withValue(CustomizerRequest(values: ["Size": "5"])) {
            await Model(tempDir.appending(path: "model").path) {
                @Parameter("Size") var size = 1.0
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

    @Test func `A request builds only its model, with its values, where it says`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let projectDir = tempDir.appending(path: "project")
        let outputDir = tempDir.appending(path: "output")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let jarDiameter = CapturedValue<Double>()
        let lidDiameter = CapturedValue<Double>()
        let request = CustomizerRequest(model: "lid", values: ["Diameter": "75"], outputDirectory: outputDir.path)

        await CustomizerRequest.$overridden.withValue(request) {
            await Project(root: projectDir) {
                await Model("jar", options: .format3D(.stl)) {
                    @Parameter("Diameter") var diameter = 60.0
                    let _ = jarDiameter.value = diameter
                    Cylinder(diameter: diameter, height: 80)
                }
                await Model("lid", options: .format3D(.stl)) {
                    @Parameter("Diameter") var diameter = 60.0
                    let _ = lidDiameter.value = diameter
                    Cylinder(diameter: diameter, height: 5)
                }
            }
        }

        #expect(lidDiameter.value == 75)
        #expect(jarDiameter.value == nil) // The other model wasn't built
        #expect(try FileManager.default.contentsOfDirectory(atPath: outputDir.path) == ["lid.stl"])
        #expect(FileManager.default.fileExists(atPath: projectDir.path) == false)
    }

    @Test func `Parameters describe their kind and metadata`() {
        @Parameter("Height", in: 10...50, step: 0.5, description: "Plate height") var height = 20.0
        @Parameter("Finish") var finish = Finish.matte
        @Parameter("Tilt") var tilt = 15°

        #expect(_height.descriptor == ParameterDescriptor(
            label: "Height", kind: .number, defaultValue: "20.0",
            minimum: "10.0", maximum: "50.0", step: "0.5", description: "Plate height"
        ))
        #expect(_finish.descriptor.kind == .choice(["matte", "glossy"]))
        #expect(_finish.descriptor.defaultValue == "matte")
        #expect(_tilt.descriptor.kind == .angle)
        #expect(Angle(parameterString: _tilt.descriptor.defaultValue) == 15°)
    }

    @Test func `Catalog collects parameters from every model without writing files`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        struct Plate: Geometry3D {
            @Parameter("Width", in: 10...100) var width = 40.0
            @Parameter("Rounded") var rounded = false
            @Parameter("Radius") var radius = 3.0 // Only read when rounded is true

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
                // The same label in the same model is the same parameter
                @Parameter("Width") var width = 40.0
                Box(width)
            }
            await Group("parts") {
                await Model("peg") {
                    Metadata(title: "Peg", description: "A peg with a configurable size")
                    @Parameter("Count", in: 1...8) var count = 3
                    @Parameter("Finish") var finish = Finish.glossy
                    Box(Double(count))
                }
            }
        }

        let json = try JSONSerialization.jsonObject(with: catalog.jsonData()) as? [String: Any]
        let models = try #require(json?["models"] as? [[String: Any]])
        let parameters = Dictionary(uniqueKeysWithValues: models.map {
            ($0["name"] as? String ?? "", ($0["parameters"] as? [[String: Any]] ?? []).compactMap { $0["label"] as? String })
        })
        #expect(parameters["parts/peg"] == ["Count", "Finish"])
        #expect(parameters[tempDir.appending(path: "plate").path] == ["Width", "Rounded", "Radius"])

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

    @Test func `Catalog reports the project's own title and description`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let catalog = await ParameterCatalog.collect(options: []) {
            Metadata(title: "Kitchen Set", description: "Containers that fit together")
            await Model(tempDir.appending(path: "jar").path) {
                Metadata(title: "Jar")
                @Parameter("Diameter") var diameter = 60.0
                Cylinder(diameter: diameter, height: 80)
            }
            await Model(tempDir.appending(path: "lid").path) {
                @Parameter("Diameter") var diameter = 60.0
                Cylinder(diameter: diameter, height: 5)
            }
        }

        let json = try #require(try JSONSerialization.jsonObject(with: catalog.jsonData()) as? [String: Any])
        #expect(json["title"] as? String == "Kitchen Set")
        #expect(json["description"] as? String == "Containers that fit together")

        // The project's metadata still applies to models that don't override it
        let models = try #require(json["models"] as? [[String: Any]])
        let titles = Dictionary(uniqueKeysWithValues: models.map {
            (URL(fileURLWithPath: $0["name"] as? String ?? "").lastPathComponent, $0["title"] as? String)
        })
        #expect(titles["jar"] == "Jar")
        #expect(titles["lid"] == "Kitchen Set")
    }

    @Test func `Listing parameters writes JSON and builds nothing`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let listURL = tempDir.appending(path: "parameters.json")

        await CustomizerRequest.$overridden.withValue(CustomizerRequest(parameterListPath: listURL.path)) {
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
        #expect((model["parameters"] as? [[String: Any]])?.first?["label"] as? String == "Size")
        #expect(try FileManager.default.contentsOfDirectory(atPath: tempDir.path) == ["parameters.json"])
    }
}
