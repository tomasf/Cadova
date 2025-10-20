import Foundation

extension GeometryNode {
    static var empty: GeometryNode {
        Self(.empty)
    }

    static func boolean(_ children: [D.Node], type: BooleanOperationType) -> GeometryNode {
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

    static func convexHull(_ body: D.Node) -> GeometryNode {
        guard body.isEmpty == false else { return .empty }
        return Self(.convexHull(body))
    }

    static func refine(_ body: D.Node, maxEdgeLength: Double) -> GeometryNode {
        guard body.isEmpty == false else { return .empty }
        return Self(.refine(body, edgeLength: maxEdgeLength))
    }

    static func simplify(_ body: D.Node, tolerance: Double) -> GeometryNode {
        guard body.isEmpty == false else { return .empty }
        return Self(.simplify(body, tolerance: tolerance))
    }

    static func transform(_ body: D.Node, transform: D.Transform) -> GeometryNode {
        guard body.isEmpty == false else { return .empty }

        if case .transform(let innerBody, let bodyTransform) = body.contents {
            let combined = bodyTransform.concatenated(with: transform)
            return Self(.transform(innerBody, transform: combined))
        }

        return Self(.transform(body, transform: transform))
    }

    static func materialized(cacheKey: OpaqueKey) -> GeometryNode {
        Self(.materialized(cacheKey: cacheKey))
    }
}

extension GeometryNode where D == D2 {
    static func shape(_ shape: PrimitiveShape2D) -> GeometryNode {
        guard shape.isEmpty == false else { return .empty }
        return Self(.shape2D(shape))
    }

    static func offset(_ body: D2.Node, amount: Double, joinStyle: LineJoinStyle, miterLimit: Double, segmentCount: Int) -> GeometryNode where D == D2 {
        guard !body.isEmpty else { return .empty }
        guard fabs(amount) > .ulpOfOne else { return body }
        return Self(.offset(body, amount: amount, joinStyle: joinStyle, miterLimit: miterLimit, segmentCount: segmentCount))
    }

    static func projection(_ body: D3.Node, type: Projection) -> GeometryNode where D == D2 {
        guard !body.isEmpty else { return .empty }
        return Self(.projection(body, type: type))
    }
}

extension GeometryNode where D == D3 {
    static func shape(_ shape: PrimitiveShape3D) -> GeometryNode {
        guard shape.isEmpty == false else { return .empty }
        return Self(.shape3D(shape))
    }

    static func extrusion(_ body: D2.Node, type: Extrusion) -> GeometryNode {
        guard body.isEmpty == false else { return .empty }
        guard type.isEmpty == false else { return .empty }
        return Self(.extrusion(body, type: type))
    }

    static func applyMaterial(_ body: D3.Node, material: Material) -> GeometryNode {
        guard body.isEmpty == false else { return .empty }
        return Self(.applyMaterial(body, material))
    }

    static func trim(_ body: D3.Node, plane: Plane) -> GeometryNode {
        guard body.isEmpty == false else { return .empty }
        return Self(.trim(body, plane))
    }
}

extension GeometryNode.PrimitiveShape2D {
    var isEmpty: Bool {
        switch self {
        case .rectangle(let size): size.x <= 0 || size.y <= 0
        case .circle(let radius, _): radius <= 0
        case .polygons(let list, _): list.count == 0
        case .convexHull(let points): points.count < 3
        }
    }
}

extension GeometryNode.PrimitiveShape3D {
    var isEmpty: Bool {
        switch self {
        case .box(let size): size.x <= 0 || size.y <= 0 || size.z <= 0
        case .sphere(let radius, _): radius <= 0
        case .cylinder(let bottom, let top, let height, _):
            (bottom <= 0 && top <= 0) || height <= 0
        case .convexHull(let points): points.count < 4
        case .mesh: false
        }
    }
}
