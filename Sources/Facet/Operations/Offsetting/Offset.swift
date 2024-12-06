import Foundation

internal struct Offset: WrappedGeometry2D {
    let body: any Geometry2D
    let amount: Double
    let style: LineJoinStyle

    let moduleName = "offset"
    var moduleParameters: CodeFragment.Parameters {
        switch style {
        case .round: ["r": amount]
        case .miter: ["delta": amount]
        case .bevel: ["delta": amount, "chamfer": true]
        }
    }

    func boundary(bodyBoundary: Bounds) -> Bounds {
        bodyBoundary.scaleOffset(amount)
    }
}

/// Describes the style of line joins in geometric shapes.
///
/// The `LineJoinStyle` enum is used to specify how the joining points between line segments or edges of a geometry should be rendered.
public enum LineJoinStyle {
    /// Joins lines with a rounded edge, creating smooth transitions between segments.
    case round

    /// Extends the outer edges of the lines until they meet at a sharp point.
    case miter

    /// Joins lines by connecting their endpoints with a straight line, resulting in a flat, cut-off corner.
    case bevel
}

public extension Geometry2D {
    /// Offsets the geometry by a specified amount.
    ///
    /// This method creates a new geometry that is offset from the original geometry's boundary. The offset can be inward, outward, or both, depending on the offset amount and line join style specified.
    ///
    /// - Parameters:
    ///   - amount: The distance by which to offset the geometry. Positive values expand the geometry outward, while negative values contract it inward.
    ///   - style: The line join style of the offset, which can be `.round`, `.miter`, or `.bevel`. Each style affects the shape of the geometry's corners differently.
    /// - Returns: A new geometry object that is the result of the offset operation.
    func offset(amount: Double, style: LineJoinStyle) -> any Geometry2D {
        Offset(body: self, amount: amount, style: style)
    }
}
