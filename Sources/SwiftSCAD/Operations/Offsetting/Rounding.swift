import Foundation

/// Specifies the side of the geometry boundary where rounding should be applied.
public enum RoundingSide {
    /// Rounding is applied only to the outside edges of the geometry.
    case outside

    /// Rounding is applied only to the inside edges of the geometry.
    case inside

    /// Rounding is applied to both the inside and outside edges of the geometry.
    case both
}

public extension Geometry2D {
    /// Applies rounding to the geometry's corners according to the specified amount and side.
    ///
    /// This method modifies the geometry to round its corners, with the extent of rounding determined by the `amount` parameter. The `side` parameter controls which side of the geometry's boundary is affected by the rounding process.
    ///
    /// - Parameters:
    ///   - amount: The radius of rounding to be applied to the geometry's corners. Positive values specify the radius of the rounding effect.
    ///   - side: The side of the geometry's boundary to apply the rounding to. Defaults to `.both`, applying rounding to both the inside and outside edges.
    /// - Returns: A new geometry object with rounded corners.
    func rounded(amount: Double, side: RoundingSide = .both) -> any Geometry2D {
        var body: any Geometry2D = self
        if side != .inside {
            body = body
                .offset(amount: -amount, style: .miter)
                .offset(amount: amount, style: .round)
        }
        if side != .outside {
            body = body
                .offset(amount: amount, style: .miter)
                .offset(amount: -amount, style: .round)
        }
        return body
    }

    /// Applies rounding to the geometry's corners but limits the effect to areas covered by a mask.
    ///
    /// This method combines the base geometry with a specified mask, rounding the geometry's corners only within the mask's boundaries. The `amount` and `side` parameters determine the extent and direction of rounding, similar to the ``rounded(amount:side:)`` method.
    ///
    /// - Parameters:
    ///   - amount: The radius of rounding to be applied to the geometry's corners. Positive values specify the radius of the rounding effect.
    ///   - side: The side of the geometry's boundary to apply the rounding to. Defaults to `.both`, applying rounding to both the inside and outside edges.
    ///   - mask: A closure that defines the mask geometry, limiting where the rounding is applied.
    /// - Returns: A new geometry object with rounded corners, limited to the area covered by the mask.

    func rounded(amount: Double, side: RoundingSide = .both, @GeometryBuilder2D in mask: () -> any Geometry2D) -> any Geometry2D {
        let maskShape = mask()
        return subtracting(maskShape)
            .adding {
                self.rounded(amount: amount, side: side)
                    .intersecting(maskShape)
            }
    }
}
