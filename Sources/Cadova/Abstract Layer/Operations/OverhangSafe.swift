import Foundation

public extension Circle {
    /// Returns a modified version of this circle with geometry adjusted to improve printability.
    ///
    /// If the shape would otherwise produce steep overhangs when printed horizontally,
    /// this method adds relief geometry — such as a pointed teardrop or bridged top —
    /// to make the shape printable without support.
    ///
    /// The overhang angle threshold is taken from the environment's `overhangAngle`,
    /// which defaults to 45° — a safe value for most FDM printers.
    ///
    /// The direction of extension depends on whether the circle is added or subtracted.
    /// When subtracted from another shape, the top side is extended upward.
    /// When added, the bottom is extended downward.
    ///
    /// The "top" direction is determined by the environment’s `naturalUpDirection`,
    /// which defaults to positive Z in world space, but can be customized via
    /// `definingNaturalUpDirection(_:)`.
    ///
    /// If the method resolves to `.none`, or if the natural up direction is perpendicular
    /// to the XY plane, the result is a regular circle without overhang relief.
    ///
    /// Relief geometry is defined relative to the XY plane, and when the up direction has
    /// no projection in that plane, the direction of extension becomes undefined.
    ///
    /// - Parameter method: The overhang relief method to use. If `nil`, the method is
    ///   inherited from the environment’s `circularOverhangMethod`.

    func overhangSafe(_ method: CircularOverhangMethod? = nil) -> any Geometry2D {
        OverhangCircle(radius: radius)
            .withEnvironment {
                if let method {
                    $0.circularOverhangMethod = method
                }
            }
    }
}

public extension Cylinder {
    /// Returns a modified version of this cylinder with geometry adjusted to improve printability.
    ///
    /// If the shape would otherwise produce steep overhangs when printed horizontally,
    /// this method adds relief geometry — such as a pointed teardrop or bridged top —
    /// to make the shape printable without support.
    ///
    /// The overhang angle threshold is taken from the environment's `overhangAngle`,
    /// which defaults to 45° — a safe value for most FDM printers.
    ///
    /// The direction of extension depends on whether the cylinder is added or subtracted.
    /// When subtracted from another shape, the top side is extended upward.
    /// When added, the bottom is extended downward.
    ///
    /// The "top" direction is determined by the environment’s `naturalUpDirection`,
    /// which defaults to positive Z in world space, but can be customized via
    /// `definingNaturalUpDirection(_:)`.
    ///
    /// If the method resolves to `.none`, or if the natural up direction is perpendicular
    /// to the XY plane, the result is a regular cylinder without overhang relief.
    ///
    /// Relief geometry is defined relative to the XY plane, and when the up direction has
    /// no projection in that plane, the direction of extension becomes undefined.
    ///
    /// - Parameter method: The overhang relief method to use. If `nil`, the method is
    ///   inherited from the environment’s `circularOverhangMethod`.
    ///
    func overhangSafe(_ style: CircularOverhangMethod? = nil) -> any Geometry3D {
        OverhangCylinder(source: self)
            .withEnvironment {
                if let style {
                    $0.circularOverhangMethod = style
                }
            }
    }
}
