import Foundation

public extension Geometry {
    /// Warps the geometry by pulling each point toward the given target point by a fixed distance.
    ///
    /// Points closer than the specified distance will be pulled directly to the target.
    /// This operation preserves the shape’s structure while creating a tapering effect toward the target.
    ///
    /// - Parameters:
    ///   - point: The point to pull toward.
    ///   - distance: The maximum distance to move each point.
    /// - Returns: A new geometry warped toward the point.
    func pulled(toward point: D.Vector, distance: Double) -> D.Geometry {
        pulled(towardTarget: point as! any PullTarget<D>, distance: distance)
    }

    /// Warps the geometry by pulling each point toward the closest point on the given line by a fixed distance.
    ///
    /// Points closer than the specified distance will be pulled directly onto the line.
    /// This operation creates a tapering effect toward the axis defined by the line.
    ///
    /// - Parameters:
    ///   - line: The line to pull toward.
    ///   - distance: The maximum distance to move each point.
    /// - Returns: A new geometry warped toward the line.
    func pulled(toward line: D.Line, distance: Double) -> D.Geometry {
        pulled(towardTarget: line, distance: distance)
    }
}

public extension Geometry3D {
    /// Warps the geometry by pulling each point toward the closest point on the given plane by a fixed distance.
    ///
    /// Points closer than the specified distance will be pulled directly onto the plane.
    /// This creates a flattening or tapering effect toward the plane surface.
    ///
    /// - Parameters:
    ///   - plane: The plane to pull toward.
    ///   - distance: The maximum distance to move each point.
    /// - Returns: A new geometry warped toward the plane.
    func pulled(toward plane: Plane, distance: Double) -> D.Geometry {
        pulled(towardTarget: plane, distance: distance)
    }
}


// MARK: - Internal

internal protocol PullTarget<D>: Sendable, Hashable, Codable {
    associatedtype D: Dimensionality
    func pullTarget(for point: D.Vector) -> D.Vector
}

internal extension Geometry {
    func pulled(towardTarget target: any PullTarget<D>, distance: Double) -> D.Geometry {
        warped(operationName: "pullTowardTargetDistance", cacheParameters: target, distance) { point in
            let offset = target.pullTarget(for: point) - point
            let length = offset.magnitude
            guard length > 1e-6 else { return point }

            let direction = offset / length
            return point + direction * min(distance, length)
        }
    }
}

extension Vector2D: PullTarget {
    func pullTarget(for point: Vector2D) -> Vector2D { self }
}

extension Vector3D: PullTarget {
    func pullTarget(for point: Vector3D) -> Vector3D { self }
}

extension Line: PullTarget {
    func pullTarget(for point: D.Vector) -> D.Vector {
        let closest = self.closestPoint(to: point)
        return closest
    }
}

extension Plane: PullTarget {
    typealias D = D3

    func pullTarget(for point: Vector3D) -> Vector3D {
        project(point: point)
    }
}
