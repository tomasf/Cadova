import Foundation
import Manifold3D

public extension EnvironmentValues {
    static private let environmentKey = Key("Cadova.RoundedCornerStyle")

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
    ///
    /// - Returns: The current `RoundedCornerStyle` for the environment.
    /// - SeeAlso: ``withRoundedCornerStyle(_:)``
    var roundedCornerStyle: RoundedCornerStyle {
        get { self[Self.environmentKey] as? RoundedCornerStyle ?? .circular }
        set { self[Self.environmentKey] = newValue }
    }

    /// Returns a copy of these environment values with a new rounded corner style applied.
    ///
    /// Use this method to set the ``roundedCornerStyle`` for a subtree of your geometry. The style
    /// will be used for all descendant geometry unless overridden further down the tree.
    ///
    /// - Parameter style: The new rounded corner style to apply.
    /// - Returns: A new ``EnvironmentValues`` with the specified style set.
    func withRoundedCornerStyle(_ style: RoundedCornerStyle) -> EnvironmentValues {
        setting(key: Self.environmentKey, value: style)
    }
}

public extension Geometry {
    /// Sets the rounded corner style for the geometry.
    ///
    /// Applies the specified ``RoundedCornerStyle`` to this geometry and all of its children,
    /// unless they override it with another style.
    ///
    /// - `.circular`: Corners follow a quarter-circle arc, producing a classic rounded look.
    /// - `.squircular`: Corners follow a squircle shape (a smooth transition between square and circle),
    ///   using a superellipse-like curve defined by the equation `x⁴ + y⁴ = r⁴`.
    ///
    /// - Parameter style: The rounded corner style to apply.
    /// - Returns: A modified geometry with the style applied in its environment.
    func withRoundedCornerStyle(_ style: RoundedCornerStyle) -> D.Geometry {
        withEnvironment { $0.withRoundedCornerStyle(style) }
    }
}
