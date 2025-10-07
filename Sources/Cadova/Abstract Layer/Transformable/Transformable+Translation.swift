import Foundation

public extension Transformable {
    /// Translate object in space.
    ///
    /// This method moves the object by a specified distance in space. The distance is represented as a vector where
    /// each component indicates the movement along the corresponding axis.
    ///
    /// - Parameters:
    ///   - distance: A `Vector2D`/`Vector3D` representing the distance to move along the axes.
    /// - Returns: A translated object.
    func translated(_ distance: T.D.Vector) -> Transformed {
        transformed(.translation(distance))
    }
}

public extension Transformable<Transform2D> {
    /// Translate object in 2D space using individual components.
    ///
    /// This method moves the object by specifying the individual distance components along the x and y axes. It
    /// allows for precise control over the translation in each direction.
    ///
    /// - Parameters:
    ///   - x: The distance to move along the x-axis.
    ///   - y: The distance to move along the y-axis.
    /// - Returns: A translated object.
    func translated(x: Double = 0, y: Double = 0) -> Transformed {
        translated([x, y])
    }
}

public extension Transformable<Transform3D> {
    /// Translate object in 3D space using a 2D vector for the x and y axes and an individual z-axis component.
    ///
    /// This method allows specifying a 2D vector for the x and y components and an individual value for the z-axis,
    /// providing flexibility when working with combined 2D and 3D coordinates.
    ///
    /// - Parameters:
    ///   - xyDistance: A `Vector2D` representing the distance to move along the x and y axes.
    ///   - z: The distance to move along the z-axis.
    /// - Returns: A translated object.
    ///
    func translated(_ xyDistance: Vector2D, z: Double) -> Transformed {
        translated(.init(xyDistance, z: z))
    }

    /// Translate object in 3D space using individual components.
    ///
    /// This method moves the object by specifying the individual distance components along the x, y, and z axes.
    /// It allows for precise control over the translation in each direction.
    ///
    /// - Parameters:
    ///   - x: The distance to move along the x-axis.
    ///   - y: The distance to move along the y-axis.
    ///   - z: The distance to move along the z-axis.
    /// - Returns: A translated object.
    func translated(x: Double = 0, y: Double = 0, z: Double = 0) -> Transformed {
        translated([x, y, z])
    }
}
