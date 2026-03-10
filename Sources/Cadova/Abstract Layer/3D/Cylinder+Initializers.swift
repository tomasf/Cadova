import Foundation

public extension Cylinder {
    // MARK: - Radius and Diameter Initializers

    /// Create a right circular cylinder
    /// - Parameters:
    ///   - radius: The radius (half diameter) of the cylinder
    ///   - height: The height of the cylinder
    init(radius: Double, height: Double) {
        assert(radius.isFinite, "Cylinder radius must be finite")
        assert(radius > 0, "Cylinder radius must be positive")
        self.init(bottom: Circle(radius: radius), top: Circle(radius: radius), height: height)
    }

    /// Create a truncated right circular cone (a cylinder with different top and bottom radii)
    /// - Parameters:
    ///   - bottomRadius: The radius at the bottom
    ///   - topRadius: The radius at the top
    ///   - height: The height between the top and the bottom
    init(bottomRadius: Double, topRadius: Double, height: Double) {
        self.init(bottom: Circle(radius: bottomRadius), top: Circle(radius: topRadius), height: height)
    }

    /// Create a right circular cylinder
    /// - Parameters:
    ///   - diameter: The diameter of the cylinder
    ///   - height: The height of the cylinder
    init(diameter: Double, height: Double) {
        self.init(bottom: Circle(diameter: diameter), top: Circle(diameter: diameter), height: height)
    }

    /// Create a truncated right circular cone (a cylinder with different top and bottom diameters)
    /// - Parameters:
    ///   - bottomDiameter: The diameter at the bottom
    ///   - topDiameter: The diameter at the top
    ///   - height: The height between the top and the bottom
    init(bottomDiameter: Double, topDiameter: Double, height: Double) {
        self.init(bottom: Circle(diameter: bottomDiameter), top: Circle(diameter: topDiameter), height: height)
    }

    /// Create a truncated right circular cone (a cylinder with different top and bottom diameters)
    /// using the slanted side length instead of vertical height.
    /// - Parameters:
    ///   - bottomDiameter: The diameter at the bottom
    ///   - topDiameter: The diameter at the top
    ///   - slantHeight: The length of the side between the top and bottom edges
    init(bottomDiameter: Double, topDiameter: Double, slantHeight: Double) {
        assert(slantHeight.isFinite, "Cylinder slant height must be finite")

        let radiusDifference = (topDiameter - bottomDiameter) / 2
        assert(
            slantHeight >= abs(radiusDifference),
            "Cylinder slant height must be at least the difference between the radii"
        )

        let height = (slantHeight * slantHeight - radiusDifference * radiusDifference).squareRoot()
        self.init(bottomDiameter: bottomDiameter, topDiameter: topDiameter, height: height)
    }

    // MARK: - Angle Initializers

    /// Create a truncated right circular cone using the bottom diameter, apex angle, and height.
    ///
    /// - Note: If a positive `apexAngle` is provided, the resulting shape expands toward the top,
    ///   so `bottomDiameter` is smaller than `topDiameter`. If a negative `apexAngle` is provided,
    ///   the shape narrows toward the top, so `bottomDiameter` is larger than `topDiameter`.
    ///
    /// - Parameters:
    ///   - bottomDiameter: The diameter at the bottom of the cone
    ///   - apexAngle: The apex angle between the two slanted sides
    ///   - height: The height between the bottom and top edges
    init(bottomDiameter: Double, apexAngle: Angle, height: Double) {
        assert(height > 0, "Cylinder height must be positive")
        assert(abs(apexAngle) > 0° && abs(apexAngle) < 180°, "Cylinder angle is outside valid range 0° < |a| < 180°")
        assert(bottomDiameter >= 0, "Bottom diameter must be non-negative")

        let topDiameter = bottomDiameter + (2 * height * tan(apexAngle / 2))
        assert(topDiameter >= 0, "Resulting top diameter is negative; check the apex angle and height")
        self.init(bottomDiameter: bottomDiameter, topDiameter: topDiameter, height: height)
    }

    /// Create a truncated right circular cone using the top diameter, apex angle, and height.
    ///
    /// - Note: If a positive `apexAngle` is provided, the resulting shape expands toward the top,
    ///   so `topDiameter` is larger than `bottomDiameter`. If a negative `apexAngle` is provided,
    ///   the shape narrows toward the top, so `topDiameter` is smaller than `bottomDiameter`.
    ///
    /// - Parameters:
    ///   - topDiameter: The diameter at the top of the cone
    ///   - apexAngle: The apex angle between the two slanted sides
    ///   - height: The height between the bottom and top edges
    init(topDiameter: Double, apexAngle: Angle, height: Double) {
        assert(height > 0, "Cylinder height must be positive")
        assert(abs(apexAngle) > 0° && abs(apexAngle) < 180°, "Cylinder angle is outside valid range 0° < |a| < 180°")
        assert(topDiameter >= 0, "Top diameter must be non-negative")

        let bottomDiameter = topDiameter - (2 * height * tan(apexAngle / 2))
        assert(bottomDiameter >= 0, "Resulting bottom diameter is negative; check the apex angle and height")
        self.init(bottomDiameter: bottomDiameter, topDiameter: topDiameter, height: height)
    }

    /// Create a truncated right circular cone (a cylinder with different top and bottom diameters)
    /// using the larger diameter (at either the bottom or top), an apex angle, and height.
    ///
    /// - Note: If a positive `apexAngle` is provided, the resulting shape expands toward the top,
    ///   with `largerDiameter` as the top diameter. If a negative `apexAngle` is provided,
    ///   the shape narrows toward the top, with `largerDiameter` as the bottom diameter.
    ///
    /// - Parameters:
    ///   - largerDiameter: The diameter at the larger end (top if expanding, bottom if narrowing)
    ///   - apexAngle: The apex angle between the two slanted sides
    ///   - height: The height between the larger and smaller ends
    init(largerDiameter: Double, apexAngle: Angle, height: Double) {
        assert(height > 0, "Cylinder height must be positive")
        assert(abs(apexAngle) > 0° && abs(apexAngle) < 180°, "Cylinder angle is outside valid range 0° < |a| < 180°")

        if apexAngle > 0° {
            // Expanding shape: `largerDiameter` is at the top
            let smallerDiameter = largerDiameter - (2 * height * tan(apexAngle / 2))
            assert(smallerDiameter >= 0, "Resulting smaller diameter is negative; check the apex angle and height")
            self.init(bottomDiameter: smallerDiameter, topDiameter: largerDiameter, height: height)
        } else {
            // Narrowing shape: `largerDiameter` is at the bottom
            let smallerDiameter = largerDiameter - (2 * height * tan(-apexAngle / 2))
            assert(smallerDiameter >= 0, "Resulting smaller diameter is negative; check the apex angle and height")
            self.init(bottomDiameter: largerDiameter, topDiameter: smallerDiameter, height: height)
        }

    }

    /// Create a truncated right circular cone (a cylinder with different top and bottom diameters)
    /// using the smaller diameter (at either the bottom or top), an apex angle, and height.
    ///
    /// - Note: If a positive `apexAngle` is provided, the resulting shape expands toward the top,
    ///   with `smallerDiameter` as the bottom diameter. If a negative `apexAngle` is provided,
    ///   the shape narrows toward the top, with `smallerDiameter` as the top diameter.
    ///
    /// - Parameters:
    ///   - smallerDiameter: The diameter at the smaller end (bottom if expanding, top if narrowing)
    ///   - apexAngle: The apex angle between the two slanted sides
    ///   - height: The height between the larger and smaller ends
    init(smallerDiameter: Double, apexAngle: Angle, height: Double) {
        assert(height > 0, "Cylinder height must be positive")
        assert(abs(apexAngle) > 0° && abs(apexAngle) < 180°, "Cylinder angle is outside valid range 0° < |a| < 180°")

        if apexAngle > 0° {
            // Expanding shape: `smallerDiameter` is at the bottom
            let largerDiameter = smallerDiameter + (2 * height * tan(apexAngle / 2))
            assert(largerDiameter >= 0, "Resulting larger diameter is negative; check the apex angle and height")
            self.init(bottomDiameter: smallerDiameter, topDiameter: largerDiameter, height: height)
        } else {
            // Narrowing shape: `smallerDiameter` is at the top
            let largerDiameter = smallerDiameter + (2 * height * tan(-apexAngle / 2))
            assert(largerDiameter >= 0, "Resulting larger diameter is negative; check the apex angle and height")
            self.init(bottomDiameter: largerDiameter, topDiameter: smallerDiameter, height: height)
        }
    }

    /// Create a truncated right circular cone (a cylinder with different top and bottom diameters)
    /// using the bottom diameter, top diameter, and apex angle.
    ///
    /// - Parameters:
    ///   - bottomDiameter: The diameter at the bottom of the cone
    ///   - topDiameter: The diameter at the top of the cone
    ///   - apexAngle: The apex angle between the two slanted sides
    init(bottomDiameter: Double, topDiameter: Double, apexAngle: Angle) {
        assert(abs(apexAngle) > 0° && abs(apexAngle) < 180°, "Apex angle is outside valid range 0° < |a| < 180°")
        assert(bottomDiameter >= 0 && topDiameter >= 0, "Diameters must be non-negative")

        // Calculate the radius difference between the bottom and top
        let radiusDifference = abs(bottomDiameter - topDiameter) / 2
        let height = radiusDifference / tan(abs(apexAngle) / 2)

        self.init(bottomDiameter: bottomDiameter, topDiameter: topDiameter, height: height)
    }

    /// Create a truncated right circular cone using the top diameter, apex angle, and slant height.
    ///
    /// - Note: If a positive `apexAngle` is provided, the resulting shape expands toward the top,
    ///   so `topDiameter` is larger than `bottomDiameter`. If a negative `apexAngle` is provided,
    ///   the shape narrows toward the top, so `topDiameter` is smaller than `bottomDiameter`.
    ///
    /// - Parameters:
    ///   - topDiameter: The diameter at the top of the cone
    ///   - apexAngle: The apex angle between the two slanted sides
    ///   - slantHeight: The length of the side between the bottom and top edges
    init(topDiameter: Double, apexAngle: Angle, slantHeight: Double) {
        assert(slantHeight > 0, "Cylinder slant height must be positive")
        assert(abs(apexAngle) > 0° && abs(apexAngle) < 180°, "Apex angle is outside valid range 0° < |a| < 180°")
        assert(topDiameter >= 0, "Top diameter must be non-negative")

        let radiusDifference = slantHeight * sin(abs(apexAngle) / 2)
        let diameterDifference = radiusDifference * 2

        if apexAngle > 0° {
            let bottomDiameter = topDiameter - diameterDifference
            assert(bottomDiameter >= 0, "Resulting bottom diameter is negative; check the apex angle and slant height")
            self.init(bottomDiameter: bottomDiameter, topDiameter: topDiameter, slantHeight: slantHeight)
        } else {
            let bottomDiameter = topDiameter + diameterDifference
            self.init(bottomDiameter: bottomDiameter, topDiameter: topDiameter, slantHeight: slantHeight)
        }
    }

    /// Create a truncated right circular cone using the bottom diameter, apex angle, and slant height.
    ///
    /// - Note: If a positive `apexAngle` is provided, the resulting shape expands toward the top,
    ///   so `bottomDiameter` is smaller than `topDiameter`. If a negative `apexAngle` is provided,
    ///   the shape narrows toward the top, so `bottomDiameter` is larger than `topDiameter`.
    ///
    /// - Parameters:
    ///   - bottomDiameter: The diameter at the bottom of the cone
    ///   - apexAngle: The apex angle between the two slanted sides
    ///   - slantHeight: The length of the side between the bottom and top edges
    init(bottomDiameter: Double, apexAngle: Angle, slantHeight: Double) {
        assert(slantHeight > 0, "Cylinder slant height must be positive")
        assert(abs(apexAngle) > 0° && abs(apexAngle) < 180°, "Apex angle is outside valid range 0° < |a| < 180°")
        assert(bottomDiameter >= 0, "Bottom diameter must be non-negative")

        let diameterDifference = 2 * slantHeight * sin(apexAngle / 2)
        let topDiameter = bottomDiameter + diameterDifference
        assert(topDiameter >= 0, "Resulting top diameter is negative; check the apex angle and slant height")
        self.init(bottomDiameter: bottomDiameter, topDiameter: topDiameter, slantHeight: slantHeight)
    }
}
