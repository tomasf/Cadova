import Foundation

internal extension EnvironmentValues {
    private static let key = Key("SwiftSCAD.NaturalUpDirection")

    struct NaturalUpDirectionData {
        let direction: Vector3D
        let transform: AffineTransform3D
    }

    var naturalUpDirectionData: NaturalUpDirectionData? {
        self[Self.key] as? NaturalUpDirectionData
    }

    func settingNaturalUpDirectionData(_ direction: NaturalUpDirectionData?) -> EnvironmentValues {
        setting(key: Self.key, value: direction)
    }
}

public extension EnvironmentValues {
    /// The natural up direction for the current environment.
    ///
    /// This computed property returns the up direction as a `Vector3D` if it has been set.
    /// The direction is adjusted based on the environment's current transformation.
    /// If no up direction is defined, it returns `nil`.
    ///
    /// The returned vector represents the "natural" up direction in the current orientation,
    /// taking into account any transformations that have been applied to the environment.
    ///
    /// - Returns: A `Vector3D` representing the natural up direction, or `nil` if not set.
    ///
    var naturalUpDirection: Vector3D? {
        naturalUpDirectionData.map { upDirection in
            let upTransform = upDirection.transform.inverse.concatenated(with: transform.inverse)
            return (upTransform.apply(to: upDirection.direction) - upTransform.offset).normalized
        }
    }

    /// The angle of the natural up direction relative to the XY plane, if defined.
    ///
    /// This computed property returns the angle between the positive X-axis and the
    /// projection of the natural up direction onto the XY plane. If the natural up
    /// direction is set, the method calculates the angle in the XY plane. If the
    /// natural up direction is not set, the method returns `nil`.
    ///
    /// - Returns: An optional `Angle` representing the angle of the natural up direction
    ///   in the XY plane, or `nil` if the natural up direction is not set.
    ///
    var naturalUpDirectionXYAngle: Angle? {
        naturalUpDirection.map { Vector2D.zero.angle(to: $0.xy) }
    }

    /// Sets the natural up direction relative to the environment's local coordinate system.
    ///
    /// This method assigns a new natural up direction to the environment, expressed as a `Vector3D`.
    /// The direction is specified relative to the environment's current local coordinate system.
    /// If the `direction` is `nil`, the natural up direction is cleared, effectively removing
    /// any specific orientation considerations from the environment.
    ///
    /// - Parameter direction: A `Vector3D` representing the new natural up direction, or `nil` to remove it.
    /// - Returns: A new `EnvironmentValues` instance with the updated natural up direction.
    ///
    func settingNaturalUpDirection(_ direction: Vector3D?) -> EnvironmentValues {
        settingNaturalUpDirectionData(direction.map {
            .init(direction: $0, transform: transform)
        })
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
    /// - Parameter direction: The `Vector3D` representing the up direction in this geometry's
    ///   coordinate system. The default value is `.up`.
    /// - Returns: A new instance of `Geometry3D` with the natural up direction set in its
    ///   environment.
    ///
    /// - See Also: `Teardrop`
    ///
    func definingNaturalUpDirection(_ direction: Vector3D = .up) -> any Geometry3D {
        withEnvironment { environment in
            environment.settingNaturalUpDirection(direction)
        }
    }

    /// Removes the natural up direction for the geometry.
    ///
    /// This method undefines the previously set natural up direction.
    /// This is useful if you want to remove any specific orientation
    /// considerations and revert to a state where the natural up
    /// direction is undefined.
    ///
    /// - Returns: A new instance of `Geometry3D` with the natural up direction unset.
    ///
    func clearingNaturalUpDirection() -> any Geometry3D {
        withEnvironment { environment in
            environment.settingNaturalUpDirection(nil)
        }
    }
}

public extension Geometry2D {
    /// Removes the natural up direction for the geometry.
    ///
    /// This method undefines the previously set natural up direction.
    /// This is useful if you want to remove any specific orientation
    /// considerations and revert to a state where the natural up
    /// direction is undefined.
    ///
    /// - Returns: A new instance of `Geometry2D` with the natural up direction unset.
    ///
    func clearingNaturalUpDirection() -> any Geometry2D {
        withEnvironment { environment in
            environment.settingNaturalUpDirection(nil)
        }
    }
}
