import Foundation
import Manifold3D

public struct GeometryResult<D: Dimensionality>: Sendable {
    internal let expression: D.Expression
    internal let elements: ResultElements

    internal init(expression: D.Expression, elements: ResultElements) {
        self.expression = expression
        self.elements = elements
    }

    internal init(combining results: [Self], operationType: BooleanOperationType) {
        self.expression = .boolean(results.map(\.expression), type: operationType)
        self.elements = .init(combining: results.map(\.elements))
    }

    internal init(_ expression: D.Expression) {
        self.init(expression: expression, elements: [:])
    }

    internal init<Key: CacheKey>(cacheKey key: Key, elements: ResultElements) {
        self.init(expression: .materialized(cacheKey: OpaqueKey(key)), elements: elements)
    }
}

public typealias GeometryResult2D = GeometryResult<D2>
public typealias GeometryResult3D = GeometryResult<D3>

internal extension GeometryResult {
    func replacing<New: Dimensionality>(expression: New.Expression) -> New.Result {
        .init(expression: expression, elements: elements)
    }

    func replacing<New: Dimensionality, Key: CacheKey>(cacheKey: Key) -> New.Result {
        .init(expression: .materialized(cacheKey: OpaqueKey(cacheKey)), elements: elements)
    }

    func replacing(elements: ResultElements) -> Self {
        .init(expression: expression, elements: elements)
    }

    func modifyingElement<E: ResultElement>(_ type: E.Type, _ modifier: (inout E) -> Void) -> Self {
        var element = elements[E.self]
        modifier(&element)
        return replacing(elements: elements.setting(element))
    }
}

extension GeometryResult: Geometry {
    public func build(in environment: EnvironmentValues, context: EvaluationContext) async -> D.Result {
        self
    }
}
