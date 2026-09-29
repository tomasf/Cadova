import Foundation

public extension Geometry3D {
    /// Hollows the geometry out, leaving a closed shell with walls of the given thickness.
    ///
    /// The cavity is the geometry offset inward by the wall thickness, following the outside's shape. Parts thinner
    /// than twice the wall thickness stay solid.
    ///
    /// The style shapes the cavity across from the outside's inside corners, where two walls meet at a concave
    /// edge. With `.round`, the default, the cavity is rounded there, so the walls are exactly the given thickness
    /// everywhere. With `.miter`, it stays sharp, like the outside, and the wall is thicker at the corner, as in a CAD
    /// shell feature; `.square` and `.bevel` cut it flat in between. Everywhere else, the cavity's edges are sharp
    /// whatever the style. The sharp styles take somewhat longer.
    ///
    /// For 2D shapes, `stroked(width:alignment:style:)` with `.inside` alignment does the same.
    ///
    /// - Parameters:
    ///   - wallThickness: The thickness of the walls.
    ///   - style: How the cavity is shaped across from inside corners. Defaults to `.round`.
    /// - Returns: The hollowed geometry.
    ///
    /// - SeeAlso: ``offset(amount:style:)``
    ///
    func hollowed(wallThickness: Double, style: LineJoinStyle = .round) -> any Geometry3D {
        subtracting {
            offset(amount: -wallThickness, style: style)
        }
    }
}
