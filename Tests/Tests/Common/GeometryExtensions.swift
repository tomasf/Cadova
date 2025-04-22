import Testing
import Foundation
@testable import Cadova

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

    func writeGoldenFile(_ name: String) async throws {
        let context = EvaluationContext()
        let result = await withDefaultSegmentation().build(in: .defaultEnvironment, context: context)

        let goldenRoot = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "golden")
        let goldenURL = goldenRoot.appending(component: name).appendingPathExtension("json")
        try result.expression.jsonData.write(to: goldenURL)

        let verificationURL = goldenRoot.appending(component: name).appendingPathExtension("3mf")
        let provider = ThreeMFDataProvider(result: result.for3MFVerification)
        try await provider.writeOutput(to: verificationURL, context: context)
    }

    func expectEquals(goldenFile name: String) async throws {
        if inGenerationMode {
            try await writeGoldenFile(name)
            return
        }

        let computedExpression = await expression
        let goldenExpression = try D.Expression(goldenFile: name)

        #expect(await expression == goldenExpression)

        if computedExpression != goldenExpression {
            logger.error("Expected: \(goldenExpression.debugDescription)")
            logger.error("Got: \(computedExpression.debugDescription)")
        }
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
