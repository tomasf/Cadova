import Foundation
import Manifold3D

public struct GeometryResult<D: Dimensionality>: Sendable {
    internal let expression: D.Expression
    internal let elements: ResultElementsByType

    internal init(expression: D.Expression, elements: ResultElementsByType) {
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
}

public typealias GeometryResult2D = GeometryResult<D2>
public typealias GeometryResult3D = GeometryResult<D3>

internal extension GeometryResult {
    func replacing<New: Dimensionality>(expression: New.Expression) -> New.Result {
        .init(expression: expression, elements: elements)
    }

    func replacing(elements: ResultElementsByType) -> Self {
        .init(expression: expression, elements: elements)
    }

    func modifyingElement<E: ResultElement>(_ type: E.Type, _ modifier: (E?) -> E?) -> Self {
        replacing(elements: elements.setting(modifier(elements[E.self])))
    }
}
