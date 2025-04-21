import Foundation
import Manifold3D

extension GeometryExpression2D {
    public func simplified() -> Self {
        switch contents {
        case .shape (let shape):
            switch shape {
            case .rectangle (let size):
                guard size.x > 0, size.y > 0 else {
                    return .empty
                }

            case .circle (let radius, _):
                guard radius > 0 else {
                    return .empty
                }

            case .polygon(let points, _):
                guard points.count >= 3 else {
                    return .empty
                }
            }

        case .boolean (let children, let operation):
            guard children.isEmpty == false else {
                return .empty
            }

            var children = children.map { $0.simplified() }

            if operation == .intersection {
                guard !children.contains(where: { $0.isEmpty }) else {
                    return .empty
                }
            } else {
                guard children.count > 0 else { return .empty }
                if operation == .difference {
                    guard children[0].isEmpty == false else { return .empty }
                }
                
                children = children.filter { !$0.isEmpty }
                if children.count == 0 {
                    return .empty
                } else if children.count == 1 {
                    return children[0]
                } else {
                    return .boolean(children, type: operation)
                }
            }

        case .transform (let expression, let type):
            guard !expression.isEmpty else { return .empty }
            return .transform(expression.simplified(), transform: type)

        case .convexHull (let expression):
            guard !expression.isEmpty else { return .empty }
            return .convexHull(expression.simplified())

        case .offset (let expression, let amount, let joinStyle, let miterLimit, let segmentCount):
            guard !expression.isEmpty else { return .empty }
            return .offset(expression.simplified(), amount: amount, joinStyle: joinStyle, miterLimit: miterLimit, segmentCount: segmentCount)

        case .projection (let expression, let type):
            guard !expression.isEmpty else { return .empty }
            return .projection(expression.simplified(), type: type)

        case .empty, .raw: break
        }

        return self
    }
}

extension GeometryExpression3D {
    public func simplified() -> Self {
        switch self {
        case .shape (let shape):
            switch shape {
            case .box (let size):
                guard size.x > 0, size.y > 0, size.z > 0 else {
                    return .empty
                }

            case .sphere (let radius, _):
                guard radius > 0 else {
                    return .empty
                }

            case .cylinder (let bottomRadius, let topRadius, let height, _):
                guard height > 0, (bottomRadius > 0 || topRadius > 0) else {
                    return .empty
                }

            case .convexHull (let points):
                guard points.count >= 3 else {
                    return .empty
                }

            case .mesh: break
            }

        case .boolean (let children, let operation):
            guard children.isEmpty == false else {
                return .empty
            }

            var children = children.map { $0.simplified() }

            if operation == .intersection {
                guard !children.contains(where: { $0.isEmpty }) else {
                    return .empty
                }
            } else {
                guard children.count > 0 else { return .empty }
                if operation == .difference {
                    guard children[0].isEmpty == false else { return .empty }
                }

                children = children.filter { !$0.isEmpty }
                if children.count == 0 {
                    return .empty
                } else if children.count == 1 {
                    return children[0]
                } else {
                    return .boolean(children, type: operation)
                }
            }

        case .transform (let expression, let transform):
            guard !expression.isEmpty else { return .empty }
            return .transform(expression.simplified(), transform: transform)

        case .convexHull (let expression):
            guard !expression.isEmpty else { return .empty }
            return .convexHull(expression.simplified())

        case .extrusion (let expression, let extrusion):
            guard !expression.isEmpty else { return .empty }

            switch extrusion {
            case .linear (let height, _, _, _):
                guard height > 0 else { return .empty }

            case .rotational (let angle, _):
                guard angle > 0° else { return .empty }
            }

            return .extrusion(expression.simplified(), type: extrusion)
        case .empty, .raw, .tag: break
        }

        return self
    }
}
