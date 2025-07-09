import Foundation

public extension EdgeProfile {
    /// Creates a chamfered edge profile, cutting the edge at a flat angle.
    /// - Parameters:
    ///   - depth: The horizontal distance from the original edge to the chamfer's farthest point.
    ///   - height: The vertical height from the base of the edge to the top of the chamfer.
    /// - Returns: An edge profile representing the chamfer.
    ///
    static func chamfer(depth: Double, height: Double) -> Self {
        Self {
            Polygon([[0, 0], [depth, 0], [0, height]])
        }
    }

    /// Creates a 45° chamfered edge profile.
    /// - Parameter depth: The depth of the chamfer along both horizontal and vertical axes.
    /// - Returns: An edge profile representing the 45° chamfer.
    ///
    static func chamfer(depth: Double) -> Self {
        .chamfer(depth: depth, height: depth)
    }

    /// Creates a chamfered edge profile with a specified width and angle.
    /// - Parameters:
    ///   - depth: The horizontal depth of the chamfer.
    ///   - angle: The angle between 0° and 90°, measured from the top of the extrusion.
    /// - Returns: An edge profile representing the chamfer with the specified angle.
    ///
    static func chamfer(depth: Double, angle: Angle) -> Self {
        assert((0°..<90°).contains(angle), "Chamfer angle must be between 0° and 90°")
        return .chamfer(depth: depth, height: depth * tan(angle))
    }

    /// Creates a chamfered edge profile with a specified height and angle.
    /// - Parameters:
    ///   - height: The vertical height of the chamfer.
    ///   - angle: The angle between 0° and 90°, measured from the top of the extrusion.
    /// - Returns: An edge profile representing the chamfer with the specified angle.
    ///
    static func chamfer(height: Double, angle: Angle) -> Self {
        assert((0°..<90°).contains(angle), "Chamfer angle must be between 0° and 90°")
        return .chamfer(depth: height / tan(angle), height: height)
    }
}

public extension EdgeProfile {
    /// Creates a rounded fillet profile with an elliptical or custom corner style.
    ///
    /// The shape of the fillet is determined by the current `CornerRoundingStyle` environment setting,
    /// which can be set using `.withCornerRoundingStyle(...)`. This allows for circular, squircular,
    /// or superelliptical rounding styles. The default style is `.circular`.
    ///
    /// - Parameters:
    ///   - depth: The horizontal distance from the original edge to the fillet's farthest point.
    ///   - height: The vertical height from the base of the edge to the top of the fillet.
    /// - Returns: An edge profile representing the rounded fillet.
    ///
    static func fillet(depth: Double, height: Double) -> Self {
        Self {
            FilletCorner(size: Vector2D(depth, height))
        }
    }

    /// Creates a rounded fillet profile using a uniform radius, with style from the environment.
    ///
    /// This method creates a rounded fillet profile where both depth and height equal the given radius.
    /// The specific shape of the fillet is controlled by the current `CornerRoundingStyle` environment setting,
    /// which supports circular, squircular, or superelliptical corner shapes. The default style is `.circular`.
    ///
    /// - Parameter radius: The radius defining the size of the corner.
    /// - Returns: An edge profile representing the rounded fillet.
    ///
    static func fillet(radius: Double) -> Self {
        .fillet(depth: radius, height: radius)
    }
}

public extension EdgeProfile {
    /// Creates an edge profile combining a smooth fillet with a straight upper edge to reduce overhang.
    ///
    /// This profile is useful in 3D printing where a rounded base is desirable but overhangs must be minimized. The
    /// curvature is shaped to reduce material cantilevering while maintaining a rounded appearance at the base.
    ///
    /// The vertical orientation of the profile is derived from the surrounding geometry's `naturalUpDirection`.
    /// The shape is contextually adapted based on the current geometric `operation`:
    /// - For `.addition`, the profile curves upward, forming a teardrop shape with its point at the bottom.
    /// - For `.subtraction`, the profile is inverted to curve downward, maintaining consistency in the removed
    ///   material boundary.
    ///
    /// - Parameter radius: The effective radius of the curved portion.
    /// - Returns: An edge profile shaped for print-friendly overhanging geometry.
    /// The shape adapts to the current `overhangAngle` environment value, allowing it to respect the maximum printable
    /// overhang angle and reduce unsupported material.
    ///
    static func overhangFillet(radius: Double) -> Self {
        Self {
            readEnvironment(\.overhangAngle) { overhangAngle in
                Circle(radius: radius)
                    .overhangSafe(.bridge)
                    .within(x: 0..., y: 0...)
            }
        }
    }
}
