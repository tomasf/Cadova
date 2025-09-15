import Foundation
import Manifold3D

/// Describes how corners between joined line segments should be treated when offsetting geometry.
///
/// The `LineJoinStyle` enum specifies the style of join applied to the corners between adjacent
/// edges during offset operations. These styles affect the appearance of corners in expanded or
/// contracted outlines, especially for convex joins.
///
public enum LineJoinStyle: Hashable, Sendable, Codable {
    /// Joins lines with a rounded corner. An arc is inserted between the edges using the offset
    /// distance as the radius.
    case round

    /// Extends offset edges to their intersection point, producing a sharp corner.
    /// If the distance between the original vertex and the intersection exceeds the miter limit
    /// set in the environment, the join will fall back to a squared join to prevent extreme spikes.
    case miter

    /// Joins lines with a flat edge connecting the endpoints of adjacent offset edges. This creates
    /// a simple, clipped appearance without extending edges.
    case bevel

    /// Truncates convex corners using a straight edge, with the midpoint of the squaring edge
    /// being exactly the offset distance from the original vertex. Produces visually neat corners
    /// similar to bevels but with more consistent spacing.
    case square

    internal var manifoldRepresentation: CrossSection.JoinType {
        switch self {
        case .round: .round
        case .miter: .miter
        case .square: .square
        case .bevel: .bevel
        }
    }
}

public extension Geometry2D {
    /// Offsets the geometry by a specified amount.
    ///
    /// This method creates a new geometry that is offset from the original geometry's boundary. The offset can be
    /// inward, outward, or both, depending on the offset amount and line join style specified.
    ///
    /// - Parameters:
    ///   - amount: The distance by which to offset the geometry. Positive values expand the geometry outward, while
    ///     negative values contract it inward.
    ///   - style: The line join style of the offset, which can be `.round`, `.miter`, or `.bevel`. Each style affects
    ///     the shape of the geometry's corners differently.
    /// - Returns: A new geometry object that is the result of the offset operation.
    ///
    func offset(amount: Double, style: LineJoinStyle) -> any Geometry2D {
        readEnvironment(\.miterLimit, \.segmentation) { miterLimit, segmentation in
            GeometryNodeTransformer(body: self) {
                .offset($0,
                        amount: amount,
                        joinStyle: style,
                        miterLimit: miterLimit,
                        segmentCount: segmentation.segmentCount(circleRadius: Swift.abs(amount))
                )
            }
        }
    }

    /// Offsets the geometry by a specified amount, providing both the original and offset geometries to a builder closure.
    ///
    /// This method creates a new geometry offset from the original by the given amount and style, and passes both the original
    /// and the offset geometry to the supplied builder closure. This enables further composition, such as visualizing both shapes,
    /// combining them, or constructing additional geometry based on their relationship.
    ///
    /// - Parameters:
    ///   - amount: The distance by which to offset the geometry. Positive values expand outward, negative values contract inward.
    ///   - style: The line join style to use for the offset (e.g., `.round`, `.miter`, `.bevel`, or `.square`).
    ///   - reader: A closure that receives both the original geometry and the offset geometry, and returns a new composed geometry.
    /// - Returns: The result of the builder closure, which can combine or further process the original and offset geometries.
    ///
    /// - SeeAlso: ``offset(amount:style:)``
    ///
    func offset<D: Dimensionality>(
        amount: Double,
        style: LineJoinStyle,
        @GeometryBuilder<D> reader: @escaping @Sendable (_ original: any Geometry2D, _ offset: any Geometry2D) -> D.Geometry
    ) -> D.Geometry {
        reader(self, offset(amount: amount, style: style))
    }
}
