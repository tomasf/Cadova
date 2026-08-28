import Foundation
import Testing
import ThreeMF
@testable import Cadova

private struct UnexpectedPart: Error {}

struct ImportTests {
    @Test func `3MF file can be imported with part filtering`() async throws {
        let modelURL = Bundle.module.url(forResource: "cube_gears", withExtension: "3mf", subdirectory: "resources")!

        try await Import(model: modelURL)
            .measuring { body, measurements in
                Empty() as D3.Geometry
                #expect(measurements.edgeCount == 38502)
                #expect(measurements.triangleCount == 25668)
            }
            .triggerEvaluation()

        try await Import(model: modelURL, parts: [.name("gear 1"), .name("gear 12")])
            .measuring { body, measurements in
                Empty() as D3.Geometry
                #expect(measurements.edgeCount == 7182)
                #expect(measurements.triangleCount == 4788)
            }
            .triggerEvaluation()
    }

    @Test func `missing part throws ModelError missingPart`() async throws {
        let modelURL = Bundle.module.url(forResource: "cube_gears", withExtension: "3mf", subdirectory: "resources")!

        do {
            _ = try await Import(model: modelURL, parts: [.name("nonexistent gear")]).measurements
            Issue.record("Expected Import<D3>.ModelError.missingPart to be thrown")
        } catch let error as Import<D3>.ModelError {
            switch error {
            case .missingPart: break // Expected
            default: Issue.record("Expected missingPart but got: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(type(of: error)) - \(error)")
        }

        do {
            _ = try await Import(model: modelURL, parts: [.partNumber("nonexistent partnumber")]).measurements
            Issue.record("Expected Import<D3>.ModelError.missingPart to be thrown")
        } catch let error as Import<D3>.ModelError {
            switch error {
            case .missingPart: break // Expected
            default: Issue.record("Expected missingPart but got: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(type(of: error)) - \(error)")
        }
    }

    @Test func `part closure returning each part unchanged matches a plain import`() async throws {
        let modelURL = Bundle.module.url(forResource: "cube_gears", withExtension: "3mf", subdirectory: "resources")!

        let geometry = Import(model: modelURL) { geometry, _ in geometry }

        let viaClosure = try await geometry.mainModelMeasurements
        let plain = try await Import(model: modelURL).mainModelMeasurements
        #expect(viaClosure.triangleCount == plain.triangleCount)

        let partNames = try await geometry.partNames
        #expect(partNames.isEmpty)
    }

    @Test func `part closure routes one part into a Part and leaves the rest out`() async throws {
        let modelURL = Bundle.module.url(forResource: "cube_gears", withExtension: "3mf", subdirectory: "resources")!
        let routedPart = Part("Routed Gear", color: .red)

        let geometry = Import(model: modelURL) { geometry, part in
            if part.name == "gear 1" {
                geometry.inPart(routedPart)
            }
        }

        let partNames = try await geometry.partNames
        #expect(partNames == ["Routed Gear"])

        // Nothing was returned outside the part, so the main output is empty, and the part holds
        // exactly the geometry a filtered import of the same gear produces.
        let mainMeasurements = try await geometry.mainModelMeasurements
        #expect(mainMeasurements.triangleCount == 0)

        let routedMeasurements = try await geometry.measurements
        let gearOnly = try await Import(model: modelURL, parts: [.name("gear 1")]).measurements
        #expect(routedMeasurements.triangleCount == gearOnly.triangleCount)
    }

    @Test func `part closure can split every part using its default name`() async throws {
        let modelURL = Bundle.module.url(forResource: "cube_gears", withExtension: "3mf", subdirectory: "resources")!

        let geometry = Import(model: modelURL) { geometry, part in
            geometry.inPart(Part(part.defaultName))
        }

        // 17 objects total (cube 7 + 16 gears — there's no "gear 7", the cube takes that slot).
        let partNames = try await geometry.partNames
        #expect(partNames.count == 17)
        #expect(partNames.contains("cube 7"))
        #expect(partNames.contains("gear 2"))
    }

    @Test func `part closure indexes the parts in file order`() async throws {
        let modelURL = Bundle.module.url(forResource: "cube_gears", withExtension: "3mf", subdirectory: "resources")!

        let geometry = Import(model: modelURL) { geometry, part in
            geometry.inPart(Part("\(part.index)"))
        }

        let partNames = try await geometry.partNames
        let indices = Set(partNames.compactMap { Int($0) })
        #expect(indices == Set(0..<17))
    }

    @Test func `part closure transformations apply to the imported geometry`() async throws {
        let modelURL = Bundle.module.url(forResource: "cube_gears", withExtension: "3mf", subdirectory: "resources")!
        let offset = Vector3D(0, 0, 25)

        let movedBounds = try await Import(model: modelURL) { geometry, _ in
            geometry.translated(offset)
        }.bounds
        let plainBounds = try await Import(model: modelURL).bounds

        let moved = try #require(movedBounds)
        let plain = try #require(plainBounds)
        let expectedMinimum = plain.minimum + offset
        let expectedMaximum = plain.maximum + offset
        #expect(moved.minimum ≈ expectedMinimum)
        #expect(moved.maximum ≈ expectedMaximum)
    }

    @Test func `part closure sees names and part numbers from the file`() async throws {
        let insert = Part("Metal Insert", color: .gray)
        let geometry: any Geometry3D = Box(10)
            .inPart(insert)
            .adding { Box(20) }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cadova-test-\(UUID().uuidString).3mf")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let context = _EvaluationContext()
        let result = try await context.buildResult(for: geometry.withDefaultSegmentation(), in: .defaultEnvironment)
        let provider = ThreeMFDataProvider(result: result, options: [], environment: .defaultEnvironment)
        try await provider.writeOutput(to: tempURL, context: context)

        // Cadova writes the part name as the object name and a file identifier as the item's
        // partnumber, so a round trip shows both fields reaching the closure.
        let reimported = Import(model: tempURL) { geometry, part in
            geometry.inPart(Part("\(part.name ?? "-")|\(part.partNumber ?? "-")"))
        }

        let partNames = try await reimported.partNames
        #expect(partNames.count == 2)
        #expect(partNames.contains { $0.hasPrefix("Metal Insert|") })
        #expect(partNames.allSatisfy { $0.hasSuffix("|-") == false })
    }

    @Test func `an error thrown by the part closure propagates`() async throws {
        let modelURL = Bundle.module.url(forResource: "cube_gears", withExtension: "3mf", subdirectory: "resources")!

        let geometry = Import(model: modelURL) { geometry, part in
            if part.name == "gear 2" {
                throw UnexpectedPart()
            }
            geometry
        }

        do {
            _ = try await geometry.measurements
            Issue.record("Expected UnexpectedPart to be thrown")
        } catch is UnexpectedPart {
            // Expected
        } catch {
            Issue.record("Unexpected error type: \(type(of: error)) - \(error)")
        }
    }

    @Test func `3MF export and import preserves geometry`() async throws {
        let geometry: any Geometry3D = Box(x: 10, y: 20, z: 30)
            .subtracting {
                Cylinder(diameter: 5, height: 100)
            }

        let originalMeasurements = try await geometry.measurements

        // Export to 3MF
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cadova-test-\(UUID().uuidString).3mf")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let context = _EvaluationContext()
        let result = try await context.buildResult(for: geometry.withDefaultSegmentation(), in: .defaultEnvironment)
        let provider = ThreeMFDataProvider(result: result, options: [], environment: .defaultEnvironment)
        try await provider.writeOutput(to: tempURL, context: context)

        // Import and verify measurements match
        let importedMeasurements = try await Import(model: tempURL).measurements

        #expect(importedMeasurements.volume ≈ originalMeasurements.volume)
        #expect(importedMeasurements.surfaceArea ≈ originalMeasurements.surfaceArea)
    }

    @Test func `3MF export sets the build's production-extension UUID to the LiveLink buildUUID`() async throws {
        let geometry: any Geometry3D = Box(x: 10, y: 20, z: 30)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cadova-test-\(UUID().uuidString).3mf")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let context = _EvaluationContext()
        let result = try await context.buildResult(for: geometry.withDefaultSegmentation(), in: .defaultEnvironment)
        let provider = ThreeMFDataProvider(result: result, options: [], environment: .defaultEnvironment)
        try await provider.writeOutput(to: tempURL, context: context)

        let reader = try ThreeMF.PackageReader(url: tempURL)
        let model = try reader.model()

        #expect(model.build.uuid == provider.buildUUID)
    }

    @Test func `pushToLiveLink completes without a listener present`() async throws {
        let geometry: any Geometry3D = Box(x: 10, y: 20, z: 30)
        let context = _EvaluationContext()
        let result = try await context.buildResult(for: geometry.withDefaultSegmentation(), in: .defaultEnvironment)
        let provider = ThreeMFDataProvider(result: result, options: [], environment: .defaultEnvironment)

        // No LiveLink listener is running in the test environment, so this should return quickly
        // without throwing, exercising the same best-effort path Model.build() relies on.
        await provider.pushToLiveLink(destination: URL(filePath: "/tmp/nonexistent.3mf"), context: context)
    }

    @Test func `STL export and import preserves geometry`() async throws {
        let geometry: any Geometry3D = Box(x: 10, y: 20, z: 30)
            .subtracting {
                Cylinder(diameter: 5, height: 100)
            }

        let originalMeasurements = try await geometry.measurements

        // Export to STL
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cadova-test-\(UUID().uuidString).stl")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let context = _EvaluationContext()
        let result = try await context.buildResult(for: geometry.withDefaultSegmentation(), in: .defaultEnvironment)
        let provider = BinarySTLDataProvider(result: result, options: [])
        try await provider.writeOutput(to: tempURL, context: context)

        // Import and verify measurements match
        let importedMeasurements = try await Import(model: tempURL).measurements

        #expect(importedMeasurements.volume ≈ originalMeasurements.volume)
        #expect(importedMeasurements.surfaceArea ≈ originalMeasurements.surfaceArea)
    }

    @Test func `STL import with parts throws appropriate error`() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cadova-test-\(UUID().uuidString)")
            .appendingPathExtension("stl")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Create a simple STL file
        let context = _EvaluationContext()
        let result = try await context.buildResult(for: Box(10).withDefaultSegmentation(), in: .defaultEnvironment)
        let provider = BinarySTLDataProvider(result: result, options: [])
        try await provider.writeOutput(to: tempURL, context: context)

        // Attempting to import with parts should fail with partsNotSupported error
        do {
            _ = try await Import(model: tempURL, parts: [.name("test")]).measurements
            Issue.record("Expected Import<D3>.ModelError.partsNotSupported to be thrown")
        } catch let error as Import<D3>.ModelError {
            switch error {
            case .partsNotSupported:
                break // Expected
            default:
                Issue.record("Expected partsNotSupported but got: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(type(of: error)) - \(error)")
        }
    }

    @Test func `STL import rejects the part-closure initializer`() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cadova-test-\(UUID().uuidString)")
            .appendingPathExtension("stl")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let context = _EvaluationContext()
        let result = try await context.buildResult(for: Box(10).withDefaultSegmentation(), in: .defaultEnvironment)
        let provider = BinarySTLDataProvider(result: result, options: [])
        try await provider.writeOutput(to: tempURL, context: context)

        do {
            _ = try await Import(model: tempURL) { geometry, _ in geometry }.measurements
            Issue.record("Expected Import<D3>.ModelError.partsNotSupported to be thrown")
        } catch let error as Import<D3>.ModelError {
            switch error {
            case .partsNotSupported:
                break // Expected
            default:
                Issue.record("Expected partsNotSupported but got: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(type(of: error)) - \(error)")
        }
    }

    @Test func `SVG export declares physical size in millimeters`() async throws {
        let geometry: any Geometry2D = Rectangle(x: 20, y: 10)
            .subtracting {
                Rectangle(x: 5, y: 4)
                    .translated(x: 10, y: 3)
            }

        let originalMeasurements = try await geometry.measurements

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cadova-test-\(UUID().uuidString).svg")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let context = _EvaluationContext()
        let result = try await context.buildResult(for: geometry.withDefaultSegmentation(), in: .defaultEnvironment)
        let provider = SVGDataProvider(result: result, options: [])
        try await provider.writeOutput(to: tempURL, context: context)

        // width/height must carry an explicit "mm" unit; a bare number defaults to
        // CSS pixels per the SVG spec, so most viewers would render this ~3.78x too small.
        let svgSource = try String(contentsOf: tempURL, encoding: .utf8)
        #expect(svgSource.contains(#"width="20mm""#))
        #expect(svgSource.contains(#"height="10mm""#))

        let importedGeometry = Import(svg: tempURL, scale: .pixels)
        let importedMeasurements = try await importedGeometry.measurements

        #expect(importedMeasurements.area ≈ originalMeasurements.area)
        #expect(importedMeasurements.contourCount == originalMeasurements.contourCount)
        #expect(importedMeasurements.boundingBox!.size ≈ originalMeasurements.boundingBox!.size)
    }
}
