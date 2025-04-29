import Foundation
import Manifold3D

public extension GeometryExpression3D {
    static var empty: GeometryExpression3D {
        Self(.empty)
    }

    static func boolean(_ children: [GeometryExpression3D], type: BooleanOperationType) -> GeometryExpression3D {
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

    static func convexHull(_ body: GeometryExpression3D) -> GeometryExpression3D {
        guard body.isEmpty == false else { return .empty }
        return Self(.convexHull(body))
    }

    static func shape(_ shape: PrimitiveShape) -> GeometryExpression3D {
        guard shape.isEmpty == false else { return .empty }
        return Self(.shape(shape))
    }

    static func transform(_ body: GeometryExpression3D, transform: AffineTransform3D) -> GeometryExpression3D {
        guard body.isEmpty == false else { return .empty }

        if case .transform (let innerBody, let bodyTransform) = body.contents {
            let combinedTransform = bodyTransform.concatenated(with: transform)
            return Self(.transform(innerBody, transform: combinedTransform))
        }

        return Self(.transform(body, transform: transform))
    }

    static func materialized(cacheKey: OpaqueKey) -> GeometryExpression3D {
        return Self(.materialized(cacheKey: cacheKey))
    }

    static func extrusion(_ body: GeometryExpression2D, type: Extrusion) -> GeometryExpression3D {
        guard body.isEmpty == false else { return .empty }
        guard type.isEmpty == false else { return .empty }
        return Self(.extrusion(body, type: type))
    }

    static func applyMaterial(_ body: GeometryExpression3D, material: Material) -> GeometryExpression3D {
        guard body.isEmpty == false else { return .empty }
        return Self(.applyMaterial(body, material))
    }

    static func lazyUnion(_ children: [GeometryExpression3D]) -> GeometryExpression3D {
        let filteredChildren = children.filter { !$0.isEmpty }
        if filteredChildren.count == 0 {
            return .empty
        } else if filteredChildren.count == 1 {
            return filteredChildren[0]
        } else {
            return Self(.lazyUnion(filteredChildren))
        }
    }
}

extension GeometryExpression3D.PrimitiveShape {
    var isEmpty: Bool {
        switch self {
        case .box(let size): size.x <= 0 || size.y <= 0 || size.z <= 0
        case .sphere(let radius, _): radius <= 0
        case .cylinder(let bottomRadius, let topRadius, let height, _):
            (bottomRadius <= 0 && topRadius <= 0) || height <= 0
        case .convexHull(let points): points.count < 4
        case .mesh: false
        }
    }
}
