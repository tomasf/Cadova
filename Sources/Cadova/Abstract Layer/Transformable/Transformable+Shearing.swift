import Foundation

public extension Transformable<Transform2D> {
    /// Applies a shearing transformation to this 2D object.
    /// - Parameters:
    ///   - axis: The axis that will be displaced, in proportion to the other axis.
    ///   - factor: The magnitude of the shear.
    /// - Returns: A sheared object.
    func sheared(_ axis: Axis2D, factor: Double) -> Transformed {
        transformed(.shearing(axis, factor: factor))
    }

    /// Applies a shearing transformation to this 2D object using an angle.
    /// - Parameters:
    ///   - axis: The axis that will be displaced, in proportion to the other axis.
    ///   - angle: The angle defining the magnitude of the shear.
    /// - Returns: A sheared object.
    func sheared(_ axis: Axis2D, angle: Angle) -> Transformed {
        transformed(.shearing(axis, angle: angle))
    }
}

public extension Transformable<Transform3D> {
    /// Applies a shearing transformation to this 3D object.
    /// - Parameters:
    ///   - axis: The primary axis that will be affected by the shear.
    ///   - otherAxis: The secondary axis that controls the direction of the shear.
    ///   - factor: The magnitude of the shear.
    /// - Returns: A sheared object.
    func sheared(_ axis: Axis3D, along otherAxis: Axis3D, factor: Double) -> Transformed {
        transformed(.shearing(axis, along: otherAxis, factor: factor))
    }

    /// Applies a shearing transformation to this 3D object using an angle.
    /// - Parameters:
    ///   - axis: The primary axis that will be affected by the shear.
    ///   - otherAxis: The secondary axis that controls the direction of the shear.
    ///   - angle: The angle defining the magnitude of the shear.
    /// - Returns: A sheared object.
    func sheared(_ axis: Axis3D, along otherAxis: Axis3D, angle: Angle) -> Transformed {
        transformed(.shearing(axis, along: otherAxis, angle: angle))
    }

    /// Shears this object, leaning one direction towards another.
    ///
    /// The plane through the origin perpendicular to `from` stays fixed, and the rest of the object slants so that
    /// the `from` direction points along `to`. Cross sections perpendicular to `from` keep their shape and their
    /// position along `from`, so an extruded part keeps its height, its profile and its volume; it only leans.
    ///
    ///     prism.sheared(to: Direction3D(x: 0.3, y: 0.1, z: 1))
    ///
    /// This is the shearing counterpart of `rotated(from:to:)`, which turns the part instead of leaning it. The two
    /// directions have to be less than 90° apart.
    ///
    /// - Parameters:
    ///   - from: The direction to lean. Defaults to `.up`.
    ///   - to: The direction it should point in afterwards.
    /// - Returns: A sheared object.
    func sheared(from: Direction3D = .up, to: Direction3D) -> Transformed {
        transformed(.shearing(from: from, to: to))
    }
}

public extension Transformable<Transform2D> {
    /// Shears this object, leaning one direction towards another.
    ///
    /// The line through the origin perpendicular to `from` stays fixed, and the rest of the object slants so that
    /// the `from` direction points along `to`. Distances measured along `from` are unchanged, as is the area of
    /// the object.
    ///
    ///     square.sheared(to: Direction2D(x: 0.5, y: 1))
    ///
    /// The two directions have to be less than 90° apart.
    ///
    /// - Parameters:
    ///   - from: The direction to lean. Defaults to `.up`.
    ///   - to: The direction it should point in afterwards.
    /// - Returns: A sheared object.
    func sheared(from: Direction2D = .up, to: Direction2D) -> Transformed {
        transformed(.shearing(from: from, to: to))
    }
}
