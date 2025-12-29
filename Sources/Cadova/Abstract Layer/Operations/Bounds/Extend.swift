import Foundation

public extension Geometry {
    /// Resizes a region of the geometry along an axis by scaling it to a new length.
    ///
    /// This method scales the geometry within a specified range to a target length,
    /// while keeping geometry outside the range intact (translated to accommodate the change).
    ///
    /// - Parameters:
    ///   - axis: The axis along which to resize.
    ///   - range: The range of the geometry to scale.
    ///   - newLength: The target length for the range. Must be non-negative.
    ///   - alignment: Which side stays fixed: `.min` (default), `.max`, or `.mid`.
    ///
    /// ## Examples
    /// ```swift
    /// // Compress the middle section of a rectangle
    /// Rectangle(x: 30, y: 10)
    ///     .resizing(.x, in: 10...20, to: 5)
    ///
    /// // Compress the middle section of a cylinder
    /// Cylinder(diameter: 20, height: 30)
    ///     .resizing(.z, in: 10...20, to: 5)
    ///
    /// // Stretch a section while keeping the top fixed
    /// box.resizing(.z, in: 5...15, to: 20, alignment: .max)
    /// ```
    ///
    @GeometryBuilder<D>
    func resizing(
        _ axis: D.Axis,
        in range: ClosedRange<Double>,
        to newLength: Double,
        alignment: AxisAlignment = .min
    ) -> D.Geometry {
        let originalLength = range.upperBound - range.lowerBound
        precondition(newLength >= 0, "New length must be non-negative")
        precondition(originalLength > 0, "Range must have positive length")

        let delta = newLength - originalLength
        let scale = newLength / originalLength

        // The point that remains fixed based on alignment
        let fixedPoint = range.lowerBound + originalLength * alignment.fraction

        // Translation amounts for sections outside the range
        let lowerTranslation = -delta * alignment.fraction
        let upperTranslation = delta * (1 - alignment.fraction)

        let axisVector = D.Direction(axis, .positive).unitVector

        measuringBounds { body, bounds in
            // Geometry below the range
            body.intersecting {
                bounds.partialBox(from: nil, to: range.lowerBound, in: axis, margin: 1).mask
            }
            .translated(axisVector * lowerTranslation)

            // Geometry within the range - scale around the fixed point
            if scale > 0 {
                body.intersecting {
                    bounds.partialBox(from: range.lowerBound, to: range.upperBound, in: axis, margin: 1).mask
                }
                .translated(axisVector * -fixedPoint)
                .scaled(D.Vector(1).with(axis, as: scale))
                .translated(axisVector * fixedPoint)
            }

            // Geometry above the range
            body.intersecting {
                bounds.partialBox(from: range.upperBound, to: nil, in: axis, margin: 1).mask
            }
            .translated(axisVector * upperTranslation)
        }
    }
}

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
