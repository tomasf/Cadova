import Foundation

public extension Geometry3D {
    /// Lengthens the geometry by a given amount at the specified plane.
    ///
    /// Use this to make a shape longer while preserving its profile. The cross-section
    /// at the plane is extended, as if stretching the geometry at that point.
    ///
    /// - Parameters:
    ///   - plane: The plane at which the extension occurs.
    ///   - amount: The distance to extend.
    ///   - alignment: Which side stays fixed: `.min` (default), `.max`, or `.mid`.
    ///
    /// ## Example
    /// ```swift
    /// // Make a bottle taller by extending its neck
    /// bottle.extending(at: Plane(z: 80), by: 20)
    /// ```
    ///
    func extending(at plane: Plane, by amount: Double, alignment: AxisAlignment = .min) -> any Geometry3D {
        precondition(amount > 0, "Extension amount must be positive")

        let normalVector = plane.normal.unitVector

        // Calculate how much each side moves based on alignment
        let upperTranslation = normalVector * amount * (1 - alignment.fraction)
        let lowerTranslation = normalVector * -amount * alignment.fraction

        return Union {
            // Geometry below the plane (facing opposite to normal)
            self.trimmed(along: plane.flipped)
                .translated(lowerTranslation)
            // Extrude the cross-section at the plane
            self.sliced(along: plane)
                .extruded(height: amount)
                .transformed(plane.transform.translated(lowerTranslation))
            // Geometry above the plane (facing normal direction)
            self.trimmed(along: plane)
                .translated(upperTranslation)
        }
    }

    /// Lengthens the geometry by a given amount at the specified position along an axis.
    ///
    /// Use this to make a shape longer while preserving its profile. The cross-section
    /// at the position is extended, as if stretching the geometry at that point.
    ///
    /// - Parameters:
    ///   - axis: The axis along which to extend.
    ///   - amount: The distance to extend.
    ///   - position: The position along the axis where the extension occurs.
    ///   - alignment: Which side stays fixed: `.min` (default), `.max`, or `.mid`.
    ///
    /// ## Example
    /// ```swift
    /// // Make a 30mm tall cylinder into a 40mm one by extending at its midpoint
    /// Cylinder(diameter: 20, height: 30)
    ///     .extending(.z, by: 10, at: 15)
    /// ```
    ///
    func extending(_ axis: Axis3D, by amount: Double, at position: Double, alignment: AxisAlignment = .min) -> any Geometry3D {
        extending(at: Plane(perpendicularTo: axis, at: position), by: amount, alignment: alignment)
    }
}
