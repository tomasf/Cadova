import Foundation

internal extension EnvironmentValues {
    private static let key = Key("Cadova.NaturalUpDirection")

    struct NaturalUpDirectionData {
        let direction: Direction3D
        let transform: Transform3D

        static let standard = Self(direction: .positiveZ, transform: .identity)
    }

    var naturalUpDirectionData: NaturalUpDirectionData {
        self[Self.key] as? NaturalUpDirectionData ?? .standard
    }

    func settingNaturalUpDirectionData(_ direction: NaturalUpDirectionData?) -> EnvironmentValues {
        setting(key: Self.key, value: direction)
    }
}

public extension EnvironmentValues {
    /// The natural up direction for the current environment.
    ///
    /// This computed property returns the up direction as a `Vector3D`.
    /// The direction is adjusted based on the environment's current transformation.
    /// The default direction is based on the positive Z axis direction in world space.
    ///
    /// The returned vector represents the "natural" up direction in the current orientation,
    /// taking into account any transformations that have been applied to the environment.
    ///
    /// - Returns: A `Vector3D` representing the natural up direction.
    ///
    var naturalUpDirection: Direction3D {
        let upDirection = naturalUpDirectionData
        let upTransform = upDirection.transform.inverse.concatenated(with: transform.inverse)
        return Direction3D(upTransform.apply(to: upDirection.direction.unitVector) - upTransform.offset)
    }

    /// The angle of the natural up direction relative to the XY plane, if defined.
    ///
    /// This computed property returns the angle between the positive X-axis and the
    /// projection of the natural up direction onto the XY plane.
    /// Returns `nil` if the natural up direction is perpendicular to the XY plane.
    ///
    /// - Returns: An optional `Angle` representing the angle of the natural up direction
    ///   in the XY plane, or `nil` if no projection exists.
    ///
    var naturalUpDirectionXYAngle: Angle? {
        let xy = naturalUpDirection.unitVector.xy
        guard xy.magnitude > 0 else { return nil }
        return Vector2D.zero.angle(to: xy)
    }

    /// Sets the natural up direction relative to the environment's local coordinate system.
    ///
    /// This method assigns a new natural up direction to the environment, expressed as a `Vector3D`.
    /// The direction is specified relative to the environment's current local coordinate system.
    ///
    /// - Parameter direction: A `Vector3D` representing the new natural up direction.
    /// - Returns: A new `EnvironmentValues` instance with the updated natural up direction.
    ///
    func settingNaturalUpDirection(_ direction: Direction3D) -> EnvironmentValues {
        settingNaturalUpDirectionData(.init(direction: direction, transform: transform))
    }
}

public extension Geometry3D {
    /// Sets the natural up direction for the geometry.
    ///
    /// This method defines the direction that is considered "up" in the natural orientation
    /// of the geometry. This is particularly useful for 3D printing applications, where
    /// the up direction affects how overhangs are to be compensated for. You can read this value
    /// through `Environment.naturalUpDirection`, where it's been transformed to match that
    /// coordinate system.
    ///
    /// - Parameter direction: The `Direction3D` representing the up direction in this geometry's
    ///   coordinate system. The default value is `.up`.
    /// - Returns: A new instance of `Geometry3D` with the natural up direction set in its
    ///   environment.
    ///
    func definingNaturalUpDirection(_ direction: Direction3D = .up) -> any Geometry3D {
        withEnvironment { environment in
            environment.settingNaturalUpDirection(direction)
        }
    }
}
