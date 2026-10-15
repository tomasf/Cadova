import Foundation
import Testing
@testable import Cadova

private enum Finish: String, ParameterChoice {
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

    static var sizeKey: String { Self()._size.key }

    var body: any Geometry3D {
        Box(size)
    }
}

// Which parameters it uses depends on the shape chosen
private struct ShapeChoice: Geometry3D {
    enum Shape: String, ParameterChoice { case box, cylinder }
    @Parameter("Shape") var shape = Shape.box

    static var shapeKey: String { Self()._shape.key }

    var body: any Geometry3D {
        switch shape {
        case .box:
            @Parameter("Width") var width = 10.0
            Box(width)
        case .cylinder:
            @Parameter("Diameter") var diameter = 10.0
            Cylinder(diameter: diameter, height: 5)
        }
    }
}

// Cached, with a stored parameter and one read only in its body
private struct CachedPlate: CachedGeometry3D {
    @Parameter("Plate width") var width = 10.0

    static var widthKey: String { Self()._width.key }

    var body: any Geometry3D {
        @Parameter("Plate height") var height = 2.0
        Box(x: width, y: 5, z: height)
    }
}

// Branches with parameters of their own, built side by side
private struct Branch: Geometry3D {
    let index: Int

    var body: any Geometry3D {
        // A little work first, so the branches finish in no particular order
        @Parameter("Size \(index)") var size = 1.0
        Sphere(diameter: size).withSegmentation(count: 8 * (5 - index))
            .adding { Box(size) }
        @Parameter("Offset \(index)") var offset = 0.0
        Box(1).translated(x: offset)
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
        @Parameter("Count") var count = 3
        @Parameter("Finish") var finish = Finish.matte
        @Parameter("Invalid") var invalid = 4
        var environment = EnvironmentValues.defaultEnvironment
        environment.parameterValues = [_count.key: "7", _finish.key: "glossy", _invalid.key: "xyz"]

        environment.whileCurrent {
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

    @Test func `Parameters are identified by their declaration, not their label`() {
        let first = ParameterDescriptor.key(label: "Width", fileID: "Model/main.swift", line: 12, column: 6)
        #expect(first == ParameterDescriptor.key(label: "Width", fileID: "Model/main.swift", line: 12, column: 6))
        #expect(first != ParameterDescriptor.key(label: "Width", fileID: "Model/main.swift", line: 13, column: 6))
        #expect(first != ParameterDescriptor.key(label: "Width", fileID: "Model/main.swift", line: 12, column: 7))
        // A declaration in a function can be given different labels
        #expect(first != ParameterDescriptor.key(label: "Depth", fileID: "Model/main.swift", line: 12, column: 6))
        // Keys are opaque, so a customizer's page doesn't reveal the model's source
        #expect(first.count == 32 && first.allSatisfy(\.isHexDigit))

        @Parameter("Size") var size = 1.0
        #expect(_size.key != ParametricBox.sizeKey)
        #expect(ParametricBox().size == 1 && ParametricBox.sizeKey == ParametricBox.sizeKey)
    }

    @Test func `Chosen values reach standalone models`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let builderValue = CapturedValue<Double>()
        let bodyVolume = CapturedValue<Double>()

        // A separate declaration with the same label is a separate parameter, with its own value
        let size = Parameter(wrappedValue: 1.0, "Size")
        let request = CustomizerRequest(values: [size.key: "2", ParametricBox.sizeKey: "5"])

        await CustomizerRequest.$overridden.withValue(request) {
            await Model(tempDir.appending(path: "model").path) {
                let _ = builderValue.value = size.wrappedValue

                ParametricBox().measuring { geometry, measurements in
                    let _ = bodyVolume.value = await measurements.volume
                    geometry
                }
            }
        }

        #expect(builderValue.value == 2)
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
        let jarParameter = Parameter(wrappedValue: 60.0, "Diameter")
        let lidParameter = Parameter(wrappedValue: 60.0, "Diameter")
        let request = CustomizerRequest(model: "lid", values: [lidParameter.key: "75"], outputDirectory: outputDir.path)

        await CustomizerRequest.$overridden.withValue(request) {
            await Project(root: projectDir) {
                await Model("jar", options: .format3D(.stl)) {
                    let diameter = jarParameter.wrappedValue
                    let _ = jarDiameter.value = diameter
                    Cylinder(diameter: diameter, height: 80)
                }
                await Model("lid", options: .format3D(.stl)) {
                    let diameter = lidParameter.wrappedValue
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

    @Test func `Previews use the preview format, and model files the model's format`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        func outputFiles(preview: Bool) async throws -> [String] {
            let outputDir = tempDir.appending(path: preview ? "preview" : "files")
            await CustomizerRequest.$overridden.withValue(CustomizerRequest(outputDirectory: outputDir.path, preview: preview)) {
                await Project(root: tempDir.appending(path: "project")) {
                    await Model("block", options: .format3D(.stl)) {
                        Box(10)
                    }
                    await Model("outline") {
                        Rectangle(10)
                    }
                    await Model("flat", options: .format2D(.threeMF)) {
                        Rectangle(10)
                    }
                }
            }
            return try FileManager.default.contentsOfDirectory(atPath: outputDir.path).sorted()
        }

        // A preview comes with the parameters the model used for it
        #expect(try await outputFiles(preview: true) == [
            "block.cadovapreview", "block.parameters.json", "flat.cadovapreview", "flat.parameters.json",
            "outline.cadovapreview", "outline.parameters.json",
        ])
        // A 2D model is SVG unless it asks for another format
        #expect(try await outputFiles(preview: false) == ["block.stl", "flat.3mf", "outline.svg"])
    }

    @Test func `A request writes a model in a group straight into its directory`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let outputDir = tempDir.appending(path: "output")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // The customizer looks for the file where it asked for it, so groups add no directories
        for model in ["plate", "extras/washer"] {
            try? FileManager.default.removeItem(at: outputDir)
            await CustomizerRequest.$overridden.withValue(CustomizerRequest(model: model, outputDirectory: outputDir.path)) {
                await Project(root: tempDir.appending(path: "project")) {
                    await Model("plate", options: .format3D(.stl)) { Box(10) }
                    await Group("extras") {
                        await Model("washer", options: .format3D(.stl)) { Cylinder(diameter: 12, height: 1.5) }
                    }
                }
            }
            let expected = URL(fileURLWithPath: model).lastPathComponent + ".stl"
            #expect(try FileManager.default.contentsOfDirectory(atPath: outputDir.path) == [expected])
        }
    }

    @Test func `A customizer's build writes the parameters it used with the values it was given`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let outputDir = tempDir.appending(path: "output")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        func labels(shape: String?) async throws -> [String] {
            try? FileManager.default.removeItem(at: outputDir)
            let values = shape.map { [ShapeChoice.shapeKey: $0] } ?? [:]
            await CustomizerRequest.$overridden.withValue(CustomizerRequest(values: values, outputDirectory: outputDir.path, preview: true)) {
                await Project(root: tempDir.appending(path: "project")) {
                    await Model("shape") { ShapeChoice() }
                }
            }
            let data = try Data(contentsOf: outputDir.appending(path: "shape.parameters.json"))
            let parameters = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            return parameters?.compactMap { $0["label"] as? String } ?? []
        }

        #expect(try await labels(shape: nil) == ["Shape", "Width"])
        #expect(try await labels(shape: "cylinder") == ["Shape", "Diameter"])
    }

    @Test func `Parameters are listed in the order of the code, however the build runs`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        for _ in 0..<20 {
            let catalog = await ParameterCatalog.collect(options: []) {
                await Model(tempDir.appending(path: "branches").path) {
                    @Parameter("First") var first = 1.0
                    Box(first)
                    for index in 0..<4 { Branch(index: index) }
                }
            }
            let json = try JSONSerialization.jsonObject(with: catalog.jsonData()) as? [String: Any]
            let labels = ((json?["models"] as? [[String: Any]])?.first?["parameters"] as? [[String: Any]])?.compactMap { $0["label"] as? String }
            #expect(labels == ["First"] + (0..<4).flatMap { ["Size \($0)", "Offset \($0)"] })
        }
    }

    @Test func `A cached geometry with a parameter is cached by its value`() async throws {
        let context = EvaluationContext()
        func width(_ value: String?) async throws -> Double? {
            var environment = EnvironmentValues.defaultEnvironment
            if let value { environment.parameterValues = [CachedPlate.widthKey: value] }
            let result = try await context.result(for: CachedPlate(), in: environment)
            let xs = result.concrete.meshGL().vertices.map(\.x)
            return xs.max().flatMap { max in xs.min().map { max - $0 } }
        }
        #expect(try await width(nil) == 10)
        #expect(try await width("25") == 25)
        #expect(try await width(nil) == 10)
    }

    @Test func `A cached geometry's parameters are recorded when its result is reused`() async throws {
        let context = EvaluationContext()
        for _ in 0..<2 {
            let result = try await ParameterRecorder.$current.withValue(ParameterRecorder()) {
                try await context.buildResult(for: CachedPlate(), in: .defaultEnvironment)
            }
            // The body only runs the first time, but its parameters travel in the cached result, in
            // the order the body uses them
            #expect(result.elements[ParameterList.self].parameters.map(\.label) == ["Plate height", "Plate width"])
        }
    }

    @Test func `Colors are written and read in hexadecimal`() {
        let color = Color(red: 1, green: 0.4, blue: 0)
        #expect(color.parameterString == "#ff6600")
        #expect(Color(parameterString: "#ff6600") == color)
        #expect(Color(parameterString: "FF6600") == color)
        #expect(Color(red: 1, green: 0.4, blue: 0, alpha: 0.5).parameterString == "#ff660080")
        #expect(Color(parameterString: "#ff6600")?.alpha == 1)
        #expect(Color(parameterString: "#ff66") == nil)
        #expect(Color(parameterString: "#gg6600") == nil)
        #expect(ParameterKind(Color.self) == .color)
        #expect(ParameterKind(String.self) == .text)
    }

    @Test func `Parameters describe their kind and metadata`() {
        @Parameter("Height", in: 10...50, step: 0.5, description: "Plate height") var height = 20.0
        @Parameter("Finish") var finish = Finish.matte
        @Parameter("Tilt") var tilt = 15°

        #expect(_height.descriptor == ParameterDescriptor(
            key: _height.key, label: "Height", kind: .number, defaultValue: "20.0",
            minimum: "10.0", maximum: "50.0", step: "0.5", unit: nil, description: "Plate height"
        ))
        #expect(_finish.descriptor.kind == .choice([.init(value: "matte", label: "Matte"), .init(value: "glossy", label: "Glossy")]))
        #expect(_finish.descriptor.defaultValue == "matte")
        #expect(_tilt.descriptor.kind == .angle)
        #expect(Angle(parameterString: _tilt.descriptor.defaultValue) == 15°)
    }

    @Test func `Choices can have any raw type and name their cases`() {
        enum Infill: Int, ParameterChoice { case sparse = 10, solid = 100 }
        enum Material: String, ParameterChoice {
            case pla, petgCF = "petg-cf", extraFine_layers

            var displayName: String {
                self == .pla ? "PLA" : Self.petgCF.rawValue
            }
        }
        enum Plain: String, ParameterChoice { case extraFine, PLA, petgCF = "x", extra_fine }

        @Parameter("Infill") var infill = Infill.solid
        #expect(_infill.descriptor.kind == .choice([.init(value: "10", label: "Sparse"), .init(value: "100", label: "Solid")]))
        #expect(_infill.descriptor.defaultValue == "100")
        #expect(Infill(parameterString: "10") == .sparse)
        #expect(Infill(parameterString: "11") == nil)
        #expect(Infill(parameterString: "sparse") == nil)

        #expect(Material.pla.displayName == "PLA")
        #expect(Material(parameterString: "petg-cf") == .petgCF)
        #expect(Plain.allCases.map(\.displayName) == ["Extra fine", "PLA", "Petg CF", "Extra fine"])
    }

    @Test func `Number parameters can have a unit`() throws {
        @Parameter("Depth", in: 1...10, step: 0.5, unit: "mm", description: "Groove depth") var depth = 2.0
        @Parameter("Count", unit: "pcs") var count = 4
        @Parameter("Holes", in: 0...4) var holes = 2

        #expect(_depth.descriptor.unit == "mm")
        #expect(_depth.descriptor.minimum == "1.0" && _depth.descriptor.step == "0.5")
        #expect(_depth.descriptor.description == "Groove depth")
        #expect(_count.descriptor.unit == "pcs" && _count.descriptor.kind == .integer)
        #expect(_holes.descriptor.unit == nil)

        // Customizers read it from the parameter list, which leaves it out when there's none
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode([_depth.descriptor, _holes.descriptor])) as? [[String: Any]]
        #expect(encoded?[0]["unit"] as? String == "mm")
        #expect(encoded?[1]["unit"] == nil)
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
                // Every use of one declaration is one parameter, but a separate declaration is a
                // separate parameter, even with the same label
                Plate()
                Plate().translated(x: 100)
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
        #expect(parameters[tempDir.appending(path: "plate").path] == ["Width", "Rounded", "Radius", "Width"])
        let keys = models.flatMap { ($0["parameters"] as? [[String: Any]] ?? []).compactMap { $0["key"] as? String } }
        #expect(keys.count == 6 && Set(keys).count == 6)

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

    @Test func `Catalog lists models in the order they're declared`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Neither alphabetical nor the order they happen to finish building in
        let catalog = await ParameterCatalog.collect(options: []) {
            await Model(tempDir.appending(path: "zebra").path) {
                @Parameter("Stripes") var stripes = 3
                Box(Double(stripes))
            }
            await Group("middle") {
                await Model("yak") {
                    @Parameter("Horns") var horns = 2
                    Box(Double(horns))
                }
                await Model("aardvark") {
                    @Parameter("Ears") var ears = 2
                    Box(Double(ears))
                }
            }
            await Model(tempDir.appending(path: "beaver").path) {
                @Parameter("Teeth") var teeth = 4
                Box(Double(teeth))
            }
        }

        let json = try #require(try JSONSerialization.jsonObject(with: catalog.jsonData()) as? [String: Any])
        let names = (json["models"] as? [[String: Any]] ?? []).map { URL(fileURLWithPath: $0["name"] as? String ?? "").lastPathComponent }
        #expect(names == ["zebra", "yak", "aardvark", "beaver"])
        // A model in a group lists the group, for a customizer's menu
        let groups = (json["models"] as? [[String: Any]] ?? []).map { $0["groups"] as? [String] }
        #expect(groups == [nil, ["middle"], ["middle"], nil])
        // The position is only for ordering, and stays out of the listing
        #expect((json["models"] as? [[String: Any]])?.allSatisfy { $0["position"] == nil } == true)
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

    @Test func `A standalone model lists its parameters like a project`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let listURL = tempDir.appending(path: "parameters.json")

        await CustomizerRequest.$overridden.withValue(CustomizerRequest(parameterListPath: listURL.path)) {
            await Model(tempDir.appending(path: "box").path, options: .format3D(.stl)) {
                Metadata(title: "Box")
                ParametricBox()
            }
        }

        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: listURL)) as? [String: Any]
        let model = try #require((json?["models"] as? [[String: Any]])?.first)
        #expect(model["title"] as? String == "Box")
        #expect((model["parameters"] as? [[String: Any]])?.first?["label"] as? String == "Size")
        #expect(try FileManager.default.contentsOfDirectory(atPath: tempDir.path) == ["parameters.json"])
    }
}
