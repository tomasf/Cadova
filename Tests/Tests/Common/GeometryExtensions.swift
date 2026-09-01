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
            try await _EvaluationContext().buildResult(for: self.withDefaultSegmentation(), in: .defaultEnvironment).node
        }
    }

    func triggerEvaluation() async throws {
        _ = try await node
    }

    var bounds: D.BoundingBox? {
        get async throws {
            let context = _EvaluationContext()
            let buildResult = try await context.buildModelResult(for: self.withDefaultSegmentation(), in: .defaultEnvironment)

            let concreteResult = try await context.result(for: buildResult.node)
            let concrete = concreteResult.concrete
            guard !concrete.isEmpty else { return nil }
            return D.BoundingBox(concrete.bounds)
        }
    }

    func measurements(for scope: MeasurementScope) async throws -> D.Measurements {
        let context = _EvaluationContext()
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
            let context = _EvaluationContext()
            let buildResult = try await context.buildResult(for: self.withDefaultSegmentation(), in: .defaultEnvironment)
            return try await context.result(for: .decompose(buildResult.node)).parts.count
        }
    }

    /// The number of copies a duplication operation emitted, counted at the node level.
    ///
    /// `partCount` and `.separated` both go through `decompose`, which merges copies that touch or
    /// coincide. That hides exactly the failure mode duplication counts need to be checked against: a
    /// copy landing on top of another one. The union node's children are neither merged nor
    /// deduplicated, so counting them reports what the operation actually emitted.
    ///
    /// The context is passed in so a sweep over many counts can share one, since building a fresh
    /// `_EvaluationContext` per call dominates the run time.
    ///
    func emittedCopyCount(in context: _EvaluationContext) async throws -> Int {
        let node = try await context.buildResult(for: withDefaultSegmentation(), in: .defaultEnvironment).node
        switch node.contents {
        case .empty: return 0
        case .boolean(let children, type: .union): return children.count
        default: return 1
        }
    }

    var parts: [Part: _BuildResult<D3>] {
        get async throws {
            try await _EvaluationContext().buildModelResult(for: self, in: .defaultEnvironment)
                .elements[PartCatalog.self].mergedOutputs
        }
    }

    var partNames: Set<String> {
        get async throws {
            try await Set(parts.keys.map(\.name))
        }
    }

    func readingOperation(_ action: @Sendable @escaping (EnvironmentValues.Operation) -> ()) -> D.Geometry {
        EnvironmentValueReader(source: self, read: \.operation) { geometry, operation in
            action(operation)
            return geometry
        }
    }

    func readingNaturalUpDirection(
        @GeometryBuilder<D> _ action: @Sendable @escaping (D.Geometry, Direction3D) -> D.Geometry
    ) -> D.Geometry {
        EnvironmentValueReader(source: self, read: \.naturalUpDirection, action: action)
    }

    func readingNaturalUpDirectionXYAngle(
        @GeometryBuilder<D> _ action: @Sendable @escaping (D.Geometry, Angle?) -> D.Geometry
    ) -> D.Geometry {
        EnvironmentValueReader(source: self, read: \.naturalUpDirectionXYAngle, action: action)
    }

    func readingNaturalUpDirection2D(
        @GeometryBuilder<D> _ action: @Sendable @escaping (D.Geometry, Direction2D?) -> D.Geometry
    ) -> D.Geometry {
        EnvironmentValueReader(source: self, read: \.naturalUpDirection2D, action: action)
    }

    func writeOutputFiles(_ name: String, types: Set<TestGeneratedOutputType>) async throws {
        let context = _EvaluationContext()
        let result = try await context.buildResult(for: withDefaultSegmentation(), in: .defaultEnvironment)

        let goldenRoot = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "golden")
        if types.contains(.node) {
            let goldenURL = goldenRoot.appending(component: name).appendingPathExtension("json")
            try GoldenRecord(result: result).write(to: goldenURL)
        }
        if types.contains(.model) {
            let verificationURL = goldenRoot.appending(component: name).appendingPathExtension("3mf")
            let provider = ThreeMFDataProvider(
                result: result.for3MFVerification, options: [], environment: .defaultEnvironment
            )
            try await provider.writeOutput(to: verificationURL, context: context)
        }
    }

    func expectEquals(goldenFile name: String) async throws {
        if let types = TestGeneratedOutputType.fromEnvironment {
            try await writeOutputFiles(name, types: types)
            return
        }

        let context = _EvaluationContext()
        let result = try await context.buildResult(for: withDefaultSegmentation(), in: .defaultEnvironment)
        let computedGoldenRecord = GoldenRecord(result: result)
        let goldenRecord = try GoldenRecord<D>(url: URL(goldenFileNamed: name, extension: "json"))

        if !(computedGoldenRecord ≈ goldenRecord) {
            let baseName = name.replacingOccurrences(of: "/", with: "_")
            Attachment.record(try computedGoldenRecord.jsonString, named: "\(baseName)-actual.json")
            Attachment.record(try goldenRecord.jsonString, named: "\(baseName)-expected.json")
        }

        #expect(computedGoldenRecord ≈ goldenRecord)
    }

    func writeVerificationModel(name: String) async throws {
        if TestGeneratedOutputType.fromEnvironment?.contains(.model) == true {
            try await writeOutputFiles(name, types: [.model])
        }
    }
}

private struct EnvironmentValueReader<D: Dimensionality, Value: Sendable>: Geometry {
    let source: D.Geometry
    let read: KeyPath<EnvironmentValues, Value>
    let action: @Sendable (D.Geometry, Value) -> D.Geometry

    var body: any Geometry<D> {
        @Environment(read) var value
        action(source, value)
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

extension _BuildResult {
    var for3MFVerification: _BuildResult<D3> {
        if let d3 = self as? _BuildResult<D3> {
            return d3
        } else if let d2 = self as? _BuildResult<D2> {
            return replacing(node: GeometryNode.extrusion(d2.node, type: .linear(height: 0.001, twist: 0°, divisions: 0, scaleTop: Vector2D(1, 1))))
        } else {
            return replacing(node: .empty)
        }
    }
}
