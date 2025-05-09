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
        attracted(toward: point, influenceRadius: .greatestFiniteMagnitude, maxMovement: distance, falloff: .none)
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
        attracted(toward: line, influenceRadius: .greatestFiniteMagnitude, maxMovement: distance, falloff: .none)
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
        attracted(toward: plane, influenceRadius: .greatestFiniteMagnitude, maxMovement: distance, falloff: .none)
    }
}
