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
}
