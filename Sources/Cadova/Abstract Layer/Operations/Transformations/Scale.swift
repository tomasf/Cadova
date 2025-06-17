import Foundation

public extension Geometry {
    /// Scale geometry uniformly or non-uniformly.
    ///
    /// This method allows scaling the geometry by a specified vector, where each component of the vector represents
    /// the scaling factor along the corresponding axis.
    ///
    /// - Parameters:
    ///   - scale: A `Vector2D`/`Vector3D` representing the scaling factors along the axes.
    /// - Returns: A scaled geometry.
    func scaled(_ scale: D.Vector) -> D.Geometry {
        transformed(.scaling(scale))
    }

    /// Scale geometry uniformly.
    ///
    /// This method scales the geometry uniformly across all axes using a single factor.
    ///
    /// - Parameters:
    ///   - factor: The uniform scaling factor.
    /// - Returns: A uniformly scaled geometry.
    func scaled(_ factor: Double) -> D.Geometry {
        scaled(D.Vector(factor))
    }

    /// Flips the geometry along the specified axes.
    ///
    /// This method reflects the geometry along the given axes by negating the coordinate values along them.
    /// It can be used to create mirrored versions of a shape or invert geometry across one or more axes.
    ///
    /// - Parameter axes: The axes across which to flip the geometry.
    /// - Returns: A new geometry instance that is mirrored across the specified axes.
    func flipped(along axes: D.Axes) -> D.Geometry {
        scaled(D.Vector(1).with(axes, as: -1))
    }
}

public extension Geometry2D {
    /// Scale geometry non-uniformly.
    ///
    /// This method allows non-uniform scaling of the geometry by specifying individual scaling factors for the x and
    /// y axes.
    ///
    /// - Parameters:
    ///   - x: The scaling factor along the x-axis.
    ///   - y: The scaling factor along the y-axis.
    /// - Returns: A non-uniformly scaled geometry.
    func scaled(x: Double = 1, y: Double = 1) -> any Geometry2D {
        scaled(Vector2D(x, y))
    }
}

public extension Geometry3D {
    /// Scale geometry non-uniformly.
    ///
    /// This method allows non-uniform scaling of the geometry by specifying individual scaling factors for the x, y,
    /// and z axes.
    ///
    /// - Parameters:
    ///   - x: The scaling factor along the x-axis.
    ///   - y: The scaling factor along the y-axis.
    ///   - z: The scaling factor along the z-axis.
    /// - Returns: A non-uniformly scaled geometry.
    func scaled(x: Double = 1, y: Double = 1, z: Double = 1) -> any Geometry3D {
        scaled(Vector3D(x, y, z))
    }
}
