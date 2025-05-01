import Foundation
import Manifold3D

/// Describes the style of line joins in geometric shapes.
///
/// The `LineJoinStyle` enum is used to specify how the joining points between line segments or edges of a geometry should be rendered.
public enum LineJoinStyle: Hashable, Sendable, Codable {
    /// Joins lines with a rounded edge, creating smooth transitions between segments.
    case round

    /// Extends the outer edges of the lines until they meet at a sharp point, limited by the miter limit set in the environment.
    case miter

    /// Joins lines by connecting their endpoints with a straight line, resulting in a flat, cut-off corner.
    case bevel

    internal var manifoldRepresentation: CrossSection.JoinType {
        switch self {
        case .round: .round
        case .miter: .miter
        case .bevel: .square
        }
    }
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
        readEnvironment(\.miterLimit, \.segmentation) { miterLimit, segmentation in
            GeometryNodeTransformer(body: self) {
                .offset(
                    $0, amount: amount, joinStyle: style, miterLimit: miterLimit,
                    segmentCount: segmentation.segmentCount(circleRadius: Swift.abs(amount))
                )
            }
        }
    }
}
