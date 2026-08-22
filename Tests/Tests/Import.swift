import Foundation
import Testing
import ThreeMF
@testable import Cadova

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
        let provider = ThreeMFDataProvider(result: result, options: [])
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
        let provider = ThreeMFDataProvider(result: result, options: [])
        try await provider.writeOutput(to: tempURL, context: context)

        let reader = try ThreeMF.PackageReader(url: tempURL)
        let model = try reader.model()

        #expect(model.build.uuid == provider.buildUUID)
    }

    @Test func `pushToLiveLink completes without a listener present`() async throws {
        let geometry: any Geometry3D = Box(x: 10, y: 20, z: 30)
        let context = _EvaluationContext()
        let result = try await context.buildResult(for: geometry.withDefaultSegmentation(), in: .defaultEnvironment)
        let provider = ThreeMFDataProvider(result: result, options: [])

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
