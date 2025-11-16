import Foundation

public extension Transformable {
    /// Scale object uniformly or non-uniformly.
    ///
    /// This method allows scaling the object by a specified vector, where each component of the vector represents
    /// the scaling factor along the corresponding axis.
    ///
    /// - Parameters:
    ///   - scale: A `Vector2D`/`Vector3D` representing the scaling factors along the axes.
    /// - Returns: A scaled object.
    func scaled(_ scale: T.D.Vector) -> Transformed {
        transformed(.scaling(scale))
    }

    /// Scale object uniformly.
    ///
    /// This method scales the object uniformly across all axes using a single factor.
    ///
    /// - Parameters:
    ///   - factor: The uniform scaling factor.
    /// - Returns: A uniformly scaled object.
    func scaled(_ factor: Double) -> Transformed {
        scaled(T.D.Vector(factor))
    }

    /// Flips the object along the specified axes.
    ///
    /// This method reflects the object along the given axes by negating the coordinate values along them.
    /// It can be used to create mirrored versions of an object or invert the object across one or more axes.
    ///
    /// - Parameter axes: The axes across which to flip the object.
    /// - Returns: A new object that is mirrored across the specified axes.
    func flipped(along axes: T.D.Axes) -> Transformed {
        scaled(T.D.Vector(1).with(axes, as: -1))
    }
}

public extension Transformable<Transform2D> {
    /// Scale object non-uniformly.
    ///
    /// This method allows non-uniform scaling of the object by specifying individual scaling factors for the x and
    /// y axes.
    ///
    /// - Parameters:
    ///   - x: The scaling factor along the x-axis.
    ///   - y: The scaling factor along the y-axis.
    /// - Returns: A non-uniformly scaled object.
    func scaled(x: Double = 1, y: Double = 1) -> Transformed {
        scaled(Vector2D(x, y))
    }
}

public extension Transformable<Transform3D> {
    /// Scale object non-uniformly.
    ///
    /// This method allows non-uniform scaling of the object by specifying individual scaling factors for the x, y,
    /// and z axes.
    ///
    /// - Parameters:
    ///   - x: The scaling factor along the x-axis.
    ///   - y: The scaling factor along the y-axis.
    ///   - z: The scaling factor along the z-axis.
    /// - Returns: A non-uniformly scaled object.
    func scaled(x: Double = 1, y: Double = 1, z: Double = 1) -> Transformed {
        scaled(Vector3D(x, y, z))
    }
}
