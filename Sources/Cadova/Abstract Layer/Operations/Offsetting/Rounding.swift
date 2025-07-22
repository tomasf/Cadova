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
}
