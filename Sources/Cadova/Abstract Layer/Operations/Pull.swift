import Foundation

public extension Geometry {
    func pulled(toward point: D.Vector, distance: Double) -> D.Geometry {
        pulled(towardTarget: point as! any PullTarget<D>, distance: distance)
    }

    func pulled(toward line: D.Line, distance: Double) -> D.Geometry {
        pulled(towardTarget: line, distance: distance)
    }
}

public extension Geometry3D {
    func pulled(toward plane: Plane, distance: Double) -> D.Geometry {
        pulled(towardTarget: plane, distance: distance)
    }
}


// MARK: - Internal

internal protocol PullTarget<D>: Sendable, Hashable, Codable {
    associatedtype D: Dimensionality
    func offset(pulling point: D.Vector) -> D.Vector
}

internal extension Geometry {
    func pulled(towardTarget target: any PullTarget<D>, distance: Double) -> D.Geometry {
        warped(operationName: "pullTowardTarget", cacheParameters: target, distance) { point in
            let offset = target.offset(pulling: point)
            let length = offset.magnitude
            guard length > 1e-6 else { return point }

            let direction = offset / length
            return point + direction * min(distance, length)
        }
    }
}

extension Vector2D: PullTarget {
    func offset(pulling point: Vector2D) -> Vector2D {
        self - point
    }
}

extension Vector3D: PullTarget {
    func offset(pulling point: Vector3D) -> Vector3D {
        self - point
    }
}

extension Line: PullTarget {
    func offset(pulling point: D.Vector) -> D.Vector {
        let closest = self.closestPoint(to: point)
        return closest - point
    }
}

extension Plane: PullTarget {
    typealias D = D3

    func offset(pulling point: Vector3D) -> Vector3D {
        project(point: point) - point
    }
}
