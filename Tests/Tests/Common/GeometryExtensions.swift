import Testing
import Foundation
@testable import Cadova

enum TestGeneratedOutputType: String, Hashable {
    case expression, model

    static var fromEnvironment: Set<Self>? {
        let strings = ProcessInfo.processInfo.environment["CADOVA_TESTS_OUTPUT_TYPES"]?.split(separator: ",") ?? []
        let values = strings.compactMap { TestGeneratedOutputType(rawValue: String($0)) }
        return values.isEmpty ? nil : Set(values)
    }
}

extension Geometry {
    var expression: D.Expression {
        get async {
            await withDefaultSegmentation().build(in: .defaultEnvironment, context: .init()).expression
        }
    }

    func triggerEvaluation() async {
        _ = await expression
    }

    var bounds: D.BoundingBox? {
        get async {
            let context = EvaluationContext()
            let result = await withDefaultSegmentation().build(in: .defaultEnvironment, context: context)
            let geometry = await context.geometry(for: result.expression)
            return D.BoundingBox(geometry.bounds)
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
        if types.contains(.expression) {
            let goldenURL = goldenRoot.appending(component: name).appendingPathExtension("json")
            try GoldenRecord(result: result).write(to: goldenURL)
        }
        if types.contains(.model) {
            let verificationURL = goldenRoot.appending(component: name).appendingPathExtension("3mf")
            let provider = ThreeMFDataProvider(result: result.for3MFVerification)
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

        if computedGoldenRecord != goldenRecord {
            logger.error("Expected: \(goldenRecord)")
            logger.error("Got: \(computedGoldenRecord)")
        }

        #expect(computedGoldenRecord == goldenRecord)
    }
}

extension GeometryResult {
    var for3MFVerification: GeometryResult<D3> {
        if let d3 = self as? GeometryResult<D3> {
            return d3
        } else if let d2 = self as? GeometryResult<D2> {
            return replacing(expression: GeometryExpression3D.extrusion(d2.expression, type: .linear(height: 0.001, twist: 0°, divisions: 0, scaleTop: Vector2D(1, 1))))
        } else {
            return replacing(expression: .empty)
        }
    }
}
