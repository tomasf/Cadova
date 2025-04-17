import Foundation
import Manifold3D

protocol GeometryExpression: Sendable, Hashable {
    associatedtype PrimitiveShape
    associatedtype D: Dimensionality

    func evaluate(in context: EvaluationContext) async -> D.Primitive
    var isCacheable: Bool { get }
    var isEmpty: Bool { get }

    static var empty: Self { get }
    static func shape(_ shape: PrimitiveShape) -> Self
    static func boolean(_ children: [Self], type: BooleanOperationType) -> Self
    static func transform(_ body: Self, transform: D.Transform) -> Self
    static func convexHull(_ body: Self) -> Self
    static func raw(_ body: D.Primitive, key: ExpressionKey?) -> Self
}

enum BooleanOperationType: String, Hashable, Sendable, Codable {
    case union
    case difference
    case intersection

    var manifoldRepresentation: Manifold3D.BooleanOperation {
        switch self {
        case .union: .union
        case .difference: .difference
        case .intersection: .intersection
        }
    }
}

