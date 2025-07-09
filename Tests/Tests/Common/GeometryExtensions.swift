import Testing
import Foundation
@testable import Cadova

enum TestGeneratedOutputType: String, Hashable {
    case node, model

    static var fromEnvironment: Set<Self>? {
        let strings = ProcessInfo.processInfo.environment["CADOVA_TESTS_OUTPUT_TYPES"]?.split(separator: ",") ?? []
        let values = strings.compactMap { TestGeneratedOutputType(rawValue: String($0)) }
        return values.isEmpty ? nil : Set(values)
    }
}

extension Geometry {
    var node: D.Node {
        get async throws {
            try await EvaluationContext().buildResult(for: self.withDefaultSegmentation(), in: .defaultEnvironment).node
        }
    }

    func triggerEvaluation() async throws {
        _ = try await node
    }

    var bounds: D.BoundingBox? {
        get async throws {
            let context = EvaluationContext()
            let concreteResult = try await context.result(for: self.withDefaultSegmentation(), in: .defaultEnvironment)
            return D.BoundingBox(concreteResult.concrete.bounds)
        }
    }

    var measurements: D.Measurements {
        get async throws {
            let context = EvaluationContext()
            let concreteResult = try await context.result(for: self.withDefaultSegmentation(), in: .defaultEnvironment)
            return D.Measurements(concrete: concreteResult.concrete)
        }
    }

    var parts: [PartIdentifier: D3.BuildResult] {
        get async throws {
            try await EvaluationContext().buildResult(for: self, in: .defaultEnvironment)
                .elements[PartCatalog.self].mergedOutputs
        }
    }

    func readingOperation(_ action: @Sendable @escaping (EnvironmentValues.Operation) -> ()) -> D.Geometry {
        readEnvironment(\.operation) {
            action($0)
            return self
        }
    }

    func readingPartNames(reader: @Sendable @escaping (Set<String>) -> Void) -> D.Geometry {
        readingResult(PartCatalog.self) { geometry, catalog in
            reader(Set(catalog.parts.keys.map(\.name)))
            return geometry
        }
    }

    func writeOutputFiles(_ name: String, types: Set<TestGeneratedOutputType>) async throws {
        let context = EvaluationContext()
        let result = try await context.buildResult(for: withDefaultSegmentation(), in: .defaultEnvironment)

        let goldenRoot = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "golden")
        if types.contains(.node) {
            let goldenURL = goldenRoot.appending(component: name).appendingPathExtension("json")
            try GoldenRecord(result: result).write(to: goldenURL)
        }
        if types.contains(.model) {
            let verificationURL = goldenRoot.appending(component: name).appendingPathExtension("3mf")
            let provider = ThreeMFDataProvider(result: result.for3MFVerification, options: [])
            try await provider.writeOutput(to: verificationURL, context: context)
        }
    }

    func readingSeparatedParts(_ reader: @Sendable @escaping ([D.Geometry]) -> Void) -> D.Geometry {
        separated { components in
            reader(components)
            return self
        }
    }

    func expectEquals(goldenFile name: String) async throws {
        if let types = TestGeneratedOutputType.fromEnvironment {
            try await writeOutputFiles(name, types: types)
            return
        }

        let context = EvaluationContext()
        let result = try await context.buildResult(for: withDefaultSegmentation(), in: .defaultEnvironment)
        let computedGoldenRecord = GoldenRecord(result: result)
        let goldenRecord = try GoldenRecord<D>(url: URL(goldenFileNamed: name, extension: "json"))

        #expect(computedGoldenRecord == goldenRecord)
    }
}

extension BuildResult {
    var for3MFVerification: BuildResult<D3> {
        if let d3 = self as? BuildResult<D3> {
            return d3
        } else if let d2 = self as? BuildResult<D2> {
            return replacing(node: GeometryNode.extrusion(d2.node, type: .linear(height: 0.001, twist: 0°, divisions: 0, scaleTop: Vector2D(1, 1))))
        } else {
            return replacing(node: .empty)
        }
    }
}
