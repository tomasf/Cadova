import Foundation

public extension EnvironmentValues {
    static private let environmentKey = Key("Cadova.CornerRoundingStyle")

    /// The style of rounded corners to use for geometry in the current environment.
    ///
    /// This property controls how rounded corners are rendered throughout the geometry tree. You can
    /// select between standard circular corners (`.circular`) and more natural squircular corners
    /// (`.squircular`). The value flows down the environment tree, applying to all descendant geometry
    /// unless overridden.
    ///
    /// - `.circular`: Corners follow a quarter-circle arc, producing a classic rounded look.
    /// - `.squircular`: Corners follow a squircle shape (a smooth transition between square and circle),
    ///   using a superellipse-like curve defined by the equation `x⁴ + y⁴ = r⁴`.
    /// - `.superelliptical(exponent:)`: Corners follow a superellipse curve `xⁿ + yⁿ = rⁿ`, where the
    ///   exponent controls the shape. Lower values produce sharper, pointier corners, while higher values
    ///   result in flatter, more rectangular corners. At `n = 2`, the result is a circular arc. At `n = 4`,
    ///   it matches a squircle. The same radius will result in visually smaller corners as the exponent increases.
    ///
    /// - Returns: The current `CornerRoundingStyle` for the environment.
    /// - SeeAlso: ``withCornerRoundingStyle(_:)``
    var cornerRoundingStyle: CornerRoundingStyle {
        get { self[Self.environmentKey] as? CornerRoundingStyle ?? .circular }
        set { self[Self.environmentKey] = newValue }
    }

    /// Returns a copy of these environment values with a new corner rounding style applied.
    ///
    /// Use this method to set the ``cornerRoundingStyle`` for a subtree of your geometry. The style
    /// will be used for all descendant geometry unless overridden further down the tree.
    ///
    /// - `.circular`: Corners follow a quarter-circle arc, producing a classic rounded look.
    /// - `.squircular`: Corners follow a squircle shape (a smooth transition between square and circle),
    ///   using a superellipse-like curve defined by the equation `x⁴ + y⁴ = r⁴`.
    /// - `.superelliptical(exponent:)`: Corners follow a superellipse curve `xⁿ + yⁿ = rⁿ`, where the
    ///   exponent controls the shape. Lower values produce sharper, pointier corners, while higher values
    ///   result in flatter, more rectangular corners. At `n = 2`, the result is a circular arc. At `n = 4`,
    ///   it matches a squircle. The same radius will result in visually smaller corners as the exponent increases.
    ///
    /// - Parameter style: The new corner rounding style to apply.
    /// - Returns: A new ``EnvironmentValues`` with the specified style set.
    func withCornerRoundingStyle(_ style: CornerRoundingStyle) -> EnvironmentValues {
        setting(key: Self.environmentKey, value: style)
    }
}

public extension Geometry {
    /// Sets the corner rounding style for the geometry.
    ///
    /// Applies the specified ``CornerRoundingStyle`` to this geometry and all of its children,
    /// unless they override it with another style.
    ///
    /// - `.circular`: Corners follow a quarter-circle arc, producing a classic rounded look.
    /// - `.squircular`: Corners follow a squircle shape (a smooth transition between square and circle),
    ///   using a superellipse-like curve defined by the equation `x⁴ + y⁴ = r⁴`.
    /// - `.superelliptical(exponent:)`: Corners follow a superellipse curve `xⁿ + yⁿ = rⁿ`, where the
    ///   exponent controls the shape. Lower values produce sharper, pointier corners, while higher values
    ///   result in flatter, more rectangular corners. At `n = 2`, the result is a circular arc. At `n = 4`,
    ///   it matches a squircle. The same radius will result in visually smaller corners as the exponent increases.
    ///
    /// - Parameter style: The corner rounding style to apply.
    /// - Returns: A modified geometry with the style applied in its environment.
    func withCornerRoundingStyle(_ style: CornerRoundingStyle) -> D.Geometry {
        withEnvironment { $0.withCornerRoundingStyle(style) }
    }
}
