import Foundation

public extension Cylinder {
    /// Create a truncated right circular cone (a cylinder with different top and bottom diameters)
    /// using the larger diameter (at either the bottom or top), an apex angle, and height.
    ///
    /// - Note: If a positive `apexAngle` is provided, the resulting shape expands toward the top,
    ///   with `largerDiameter` as the top diameter. If a negative `apexAngle` is provided,
    ///   the shape narrows toward the top, with `largerDiameter` as the bottom diameter.
    ///
    /// - Parameters:
    ///   - largerDiameter: The diameter at the larger end (top if expanding, bottom if narrowing)
    ///   - apexAngle: The apex angle (in degrees) between the two slanted sides
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
    ///   - apexAngle: The apex angle (in degrees) between the two slanted sides
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
    ///   - apexAngle: The apex angle (in degrees) between the two slanted sides
    init(bottomDiameter: Double, topDiameter: Double, apexAngle: Angle) {
        assert(abs(apexAngle) > 0° && abs(apexAngle) < 180°, "Apex angle is outside valid range 0° < |a| < 180°")
        assert(bottomDiameter >= 0 && topDiameter >= 0, "Diameters must be non-negative")

        // Calculate the radius difference between the bottom and top
        let radiusDifference = abs(bottomDiameter - topDiameter) / 2
        let height = radiusDifference / tan(abs(apexAngle) / 2)

        self.init(bottomDiameter: bottomDiameter, topDiameter: topDiameter, height: height)
    }
}
