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
            let buildResult = try await context.buildModelResult(for: self.withDefaultSegmentation(), in: .defaultEnvironment)

            let concreteResult = try await context.result(for: buildResult.node)
            let concrete = concreteResult.concrete
            guard !concrete.isEmpty else { return nil }
            return D.BoundingBox(concrete.bounds)
        }
    }

    func measurements(for scope: MeasurementScope) async throws -> D.Measurements {
        let context = EvaluationContext()
        let buildResult = try await context.buildResult(for: self.withDefaultSegmentation(), in: .defaultEnvironment)
        return try await D.Measurements(buildResult: buildResult, scope: scope, context: context)
    }

    var measurements: D.Measurements {
        get async throws { try await measurements(for: .solidParts) }
    }

    var mainModelMeasurements: D.Measurements {
        get async throws { try await measurements(for: .mainPart) }
    }

    var partCount: Int {
        get async throws {
            let context = EvaluationContext()
            let buildResult = try await context.buildResult(for: self.withDefaultSegmentation(), in: .defaultEnvironment)
            return try await context.result(for: .decompose(buildResult.node)).parts.count
        }
    }

    var parts: [Part: D3.BuildResult] {
        get async throws {
            try await EvaluationContext().buildModelResult(for: self, in: .defaultEnvironment)
                .elements[PartCatalog.self].mergedOutputs
        }
    }

    var partNames: Set<String> {
        get async throws {
            try await Set(parts.keys.map(\.name))
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

    func writeVerificationModel(name: String) async throws {
        if TestGeneratedOutputType.fromEnvironment?.contains(.model) == true {
            try await writeOutputFiles(name, types: [.model])
        }
    }
}

extension Geometry where D == D2 {
    /// Compares this 2D geometry to an expected shape using XOR.
    /// Returns the area of the symmetric difference - should be near zero if shapes match.
    func symmetricDifferenceArea(with expected: some Geometry2D) async throws -> Double {
        let difference = self.adding(expected).subtracting(self.intersecting(expected))
        return try await difference.measurements.area
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
