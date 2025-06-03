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
    /// Creates an edge profile combining a rounded fillet with a straight chamfer near the top or bottom.
    /// Useful for 3D printing where bottom edges require limited overhang.
    /// The overhang angle is determined from `EnvironmentValues.overhangAngle`; set it with `.withOverhangAngle(_:)`.
    /// - Parameter radius: The radius of the curvature applied to the edge.
    /// - Returns: An edge profile representing the overhang fillet.
    ///
    static func overhangFillet(radius: Double) -> Self {
        Self {
            readEnvironment(\.overhangAngle) { overhangAngle in
                Teardrop(radius: radius, style: .flat)
                    .within(x: 0..., y: 0...)
            }
        }
    }
}
