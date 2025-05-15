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
        get async {
            await withDefaultSegmentation().build(in: .defaultEnvironment, context: .init()).node
        }
    }

    func triggerEvaluation() async {
        _ = await node
    }

    var bounds: D.BoundingBox? {
        get async {
            let context = EvaluationContext()
            let result = await withDefaultSegmentation().build(in: .defaultEnvironment, context: context)
            let nodeResult = await context.result(for: result.node)
            return D.BoundingBox(nodeResult.concrete.bounds)
        }
    }

    var measurements: D.Measurements {
        get async {
            let context = EvaluationContext()
            let result = await withDefaultSegmentation().build(in: .defaultEnvironment, context: context)
            let nodeResult = await context.result(for: result.node)
            return D.Measurements(concrete: nodeResult.concrete)
        }
    }

    var parts: [PartIdentifier: D3.BuildResult] {
        get async {
            await build(in: .defaultEnvironment, context: .init())
                .elements[PartCatalog.self].mergedOutputs
        }
    }

    func readingOperation(_ action: @Sendable @escaping (EnvironmentValues.Operation) -> ()) -> D.Geometry {
        readEnvironment(\.operation) {
            action($0)
            return self
        }
    }

    func writeOutputFiles(_ name: String, types: Set<TestGeneratedOutputType>) async throws {
        let context = EvaluationContext()
        let result = await withDefaultSegmentation().build(in: .defaultEnvironment, context: context)

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

        let result = await withDefaultSegmentation().build(in: .defaultEnvironment, context: .init())
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
