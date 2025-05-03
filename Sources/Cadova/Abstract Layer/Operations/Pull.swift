import Foundation

public extension Geometry3D {
    /// Pull each point of the geometry toward a line by a fixed distance.
    ///
    /// For every point in the geometry, this method computes the closest point on the given line
    /// and moves the point toward it by the specified distance. If the point is closer to the line
    /// than the specified distance, it is moved directly onto the line.
    ///
    /// - Parameters:
    ///   - line: The target line to attract vertices toward.
    ///   - distance: The distance each point is moved toward the line.
    /// - Returns: A new geometry with the warping applied.
    func pulled(toward line: Line<D3>, distance: Double) -> any Geometry3D {
        warped(operationName: "pullTowardLine", cacheParameters: line, distance) { point in
            let closest = line.closestPoint(to: point)
            let offset = closest - point
            let length = offset.magnitude

            guard length > 1e-6 else { return point }

            let direction = offset / length
            return point + direction * min(distance, length)
        }
    }

    /// Pull each point of the geometry toward a plane by a fixed distance.
    ///
    /// For every point in the geometry, this method computes the closest point on the given plane
    /// and moves the point toward it by the specified distance. If the point is closer to the plane
    /// than the specified distance, it is moved directly onto the plane.
    ///
    /// - Parameters:
    ///   - plane: The target plane to attract vertices toward.
    ///   - distance: The distance each point is moved toward the plane.
    /// - Returns: A new geometry with the warping applied.
    func pulled(toward plane: Plane, distance: Double) -> any Geometry3D {
        warped(operationName: "pullTowardPlane", cacheParameters: plane, distance) { point in
            let projected = plane.project(point: point)
            let offset = projected - point
            let length = offset.magnitude

            guard length > 1e-6 else { return point }

            let direction = offset / length
            return point + direction * min(distance, length)
        }
    }

    /// Pull each point of the geometry toward a fixed point by a specified distance.
    ///
    /// For every point in the geometry, this method moves it toward the given point by up to the specified distance.
    /// If the point is closer than the given distance, it is moved directly to the target point.
    ///
    /// - Parameters:
    ///   - target: The point to attract vertices toward.
    ///   - distance: The distance each point is moved toward the target.
    /// - Returns: A new geometry with the warping applied.
    func pulled(toward target: Vector3D, distance: Double) -> any Geometry3D {
        warped(operationName: "pullTowardPoint", cacheParameters: target, distance) { point in
            let offset = target - point
            let length = offset.magnitude

            guard length > 1e-6 else { return point }

            let direction = offset / length
            return point + direction * min(distance, length)
        }
    }
}
