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
}
