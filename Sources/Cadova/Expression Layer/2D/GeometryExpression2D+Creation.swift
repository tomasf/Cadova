import Foundation
import Manifold3D

public extension GeometryExpression2D {
    static var empty: GeometryExpression2D {
        Self(.empty)
    }

    static func boolean(_ children: [GeometryExpression2D], type: BooleanOperationType) -> GeometryExpression2D {
        guard children.isEmpty == false else { return .empty }

        switch type {
        case .difference:
            guard children[0].isEmpty == false else { return .empty }

        case .intersection:
            guard children.isEmpty == false else { return .empty }
            guard children.count > 1 else { return children[0] }
            guard children.contains(where: \.isEmpty) == false else { return .empty }
            return Self(.boolean(children, type: type))

        case .union: break
        }

        let filteredChildren = children.filter { !$0.isEmpty }
        if filteredChildren.count == 0 {
            return .empty
        } else if filteredChildren.count == 1 {
            return filteredChildren[0]
        } else {
            return Self(.boolean(filteredChildren, type: type))
        }
    }

    static func convexHull(_ body: GeometryExpression2D) -> GeometryExpression2D {
        guard body.isEmpty == false else { return .empty }
        return Self(.convexHull(body))
    }

    static func shape(_ shape: PrimitiveShape) -> GeometryExpression2D {
        guard shape.isEmpty == false else { return .empty }
        return Self(.shape(shape))
    }

    static func transform(_ body: GeometryExpression2D, transform: AffineTransform2D) -> GeometryExpression2D {
        guard body.isEmpty == false else { return .empty }

        if case .transform (let innerBody, let bodyTransform) = body.contents {
            let combinedTransform = bodyTransform.concatenated(with: transform)
            return Self(.transform(innerBody, transform: combinedTransform))
        }

        return Self(.transform(body, transform: transform))
    }

    static func materialized(cacheKey: OpaqueKey) -> GeometryExpression2D {
        return Self(.materialized(cacheKey: cacheKey))
    }

    static func offset(_ body: GeometryExpression2D, amount: Double, joinStyle: LineJoinStyle, miterLimit: Double, segmentCount: Int) -> GeometryExpression2D {
        guard !body.isEmpty else { return .empty }
        guard fabs(amount) > .ulpOfOne else { return .empty }
        return Self(.offset(body, amount: amount, joinStyle: joinStyle, miterLimit: miterLimit, segmentCount: segmentCount))
    }

    static func projection(_ body: GeometryExpression3D, type: Projection) -> GeometryExpression2D {
        guard !body.isEmpty else { return .empty }
        return Self(.projection(body, type: type))
    }
}

extension GeometryExpression2D.PrimitiveShape {
    var isEmpty: Bool {
        switch self {
        case .rectangle (let size): size.x <= 0 || size.y <= 0
        case .circle (let radius, _): radius <= 0
        case .polygon(let points, _): points.count < 3
        }
    }
}
