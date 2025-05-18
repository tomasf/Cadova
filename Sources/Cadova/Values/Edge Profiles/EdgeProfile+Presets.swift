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
    /// Creates a rounded fillet profile with an elliptical shape.
    /// - Parameters:
    ///   - depth: The horizontal distance from the original edge to the fillet's farthest point, defining the fillet's depth.
    ///   - height: The vertical height from the base of the edge to the top of the fillet.
    /// - Returns: An edge profile representing the elliptical fillet.
    ///
    static func fillet(depth: Double, height: Double) -> Self {
        Self {
            Circle.ellipse(x: depth * 2, y: height * 2)
                .within(x: 0..., y: 0...)
        }
    }

    /// Creates a rounded fillet profile with a circular shape.
    /// - Parameter radius: The radius of the curvature applied to the edge, defining the fillet's size.
    /// - Returns: An edge profile representing the circular fillet.
    ///
    static func fillet(radius: Double) -> Self {
        .fillet(depth: radius, height: radius)
    }
}

public extension EdgeProfile {
    /// Creates a rounded fillet profile using a squircular (superellipse) shape.
    ///
    /// A squircular fillet provides a softer, more square-like rounding compared to a circular fillet,
    /// often used for a more modern or stylized look. The shape is defined by a superellipse and
    /// appears tighter than a circular fillet with the same radius.
    ///
    /// - Parameter radius: The radius defining the size of the squircular corner.
    /// - Returns: An edge profile representing the soft fillet.
    ///
    static func softFillet(radius: Double) -> Self {
        Self {
            SquircularCorner(radius: radius)
        }
    }
}

public extension EdgeProfile {
    /// Creates an inverted fillet profile with a circular shape.
    /// - Parameter radius: The radius of the inverted fillet.
    /// - Returns: An edge profile representing the inverted fillet.
    ///
    static func invertedFillet(radius: Double) -> Self {
        .invertedFillet(depth: radius, height: radius)
    }

    /// Creates an inverted fillet profile with an elliptical shape.
    /// - Parameters:
    ///   - depth: The horizontal distance from the original edge to the fillet's farthest point.
    ///   - height: The vertical height from the base of the edge to the top of the fillet.
    /// - Returns: An edge profile representing the inverted elliptical fillet.
    ///
    static func invertedFillet(depth: Double, height: Double) -> Self {
        Self {
            Rectangle(x: depth, y: height)
                .aligned(at: .max)
                .subtracting {
                    Circle.ellipse(x: depth * 2, y: height * 2)
                }
        }
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
                Circle(radius: radius)
                    .convexHull(adding: [0, radius / sin(overhangAngle)])
                    .intersecting {
                        Rectangle(radius)
                    }
            }
        }
    }
}
