import Foundation

public extension Geometry2D {
    /// Applies rounding to the geometry's corners with separate control over inside and outside radii.
    ///
    /// This method modifies the geometry to round its corners, with the extent of rounding determined by the
    /// `insideRadius` and `outsideRadius` parameters. Positive values specify the radius of the rounding effect. If
    /// only one of the parameters is specified, rounding will be applied only on that side.
    ///
    /// - Parameters:
    ///   - insideRadius: The radius of rounding applied to interior corners of the geometry.
    ///   - outsideRadius: The radius of rounding applied to exterior corners of the geometry.
    /// - Returns: A new geometry object with rounded corners.
    ///
    func rounded(insideRadius: Double? = nil, outsideRadius: Double? = nil) -> any Geometry2D {
        var body: any Geometry2D = self
        if let outsideRadius {
            body = body
                .offset(amount: -outsideRadius, style: .miter)
                .offset(amount: outsideRadius, style: .round)
        }
        if let insideRadius {
            body = body
                .offset(amount: insideRadius, style: .miter)
                .offset(amount: -insideRadius, style: .round)
        }
        return body
    }

    /// Applies uniform rounding to both inside and outside corners of the geometry.
    ///
    /// This is a convenience method that applies the same rounding radius to both the inside and outside edges of the
    /// geometry. Equivalent to calling `rounded(insideRadius:radius, outsideRadius:radius)`.
    ///
    /// - Parameter radius: The radius to apply to both inside and outside edges.
    /// - Returns: A new geometry object with uniformly rounded corners.
    ///
    func rounded(radius: Double) -> any Geometry2D {
        rounded(insideRadius: radius, outsideRadius: radius)
    }

    /// Applies uniform rounding to the geometry's corners, limited to areas covered by a mask.
    ///
    /// This is a convenience method that applies the same rounding radius to both inside and outside edges,
    /// but restricts the effect to the area defined by the given mask.
    /// Equivalent to calling `rounded(insideRadius:radius, outsideRadius:radius, in: mask)`.
    ///
    /// - Parameters:
    ///   - radius: The radius to apply to both inside and outside edges.
    ///   - mask: A closure that defines the mask geometry, limiting where the rounding is applied.
    /// - Returns: A new geometry object with rounded corners, limited to the area covered by the mask.
    func rounded(radius: Double, @GeometryBuilder2D in mask: @Sendable @escaping () -> any Geometry2D) -> any Geometry2D {
        rounded(insideRadius: radius, outsideRadius: radius, in: mask)
    }

    /// Applies rounding to the geometry's corners with separate inside and outside radii, limited to areas covered by
    /// a mask.
    ///
    /// This method combines the base geometry with a specified mask, rounding the geometry's corners only within the
    /// mask's boundaries. The `insideRadius` and `outsideRadius` parameters determine the extent of rounding on each
    /// side, respectively.
    ///
    /// - Parameters:
    ///   - insideRadius: The radius of rounding applied to the inside edges of the geometry. Optional.
    ///   - outsideRadius: The radius of rounding applied to the outside edges of the geometry. Optional.
    ///   - mask: A closure that defines the mask geometry, limiting where the rounding is applied.
    /// - Returns: A new geometry object with rounded corners, limited to the area covered by the mask.
    ///
    func rounded(
        insideRadius: Double? = nil,
        outsideRadius: Double? = nil,
        @GeometryBuilder2D in mask: @Sendable @escaping () -> any Geometry2D
    ) -> any Geometry2D {
        let maskShape = Deferred(mask)
        return subtracting(maskShape)
            .adding {
                self.rounded(insideRadius: insideRadius, outsideRadius: outsideRadius)
                    .intersecting(maskShape)
            }
    }
}
