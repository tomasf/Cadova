import Foundation

/// Specifies how a stroke is aligned relative to the original geometry's boundary.
///
/// When stroking a 2D shape, the stroke can be placed inside, outside, or centered
/// on the original boundary. This affects the final dimensions of the stroked geometry.
///
public enum StrokeAlignment: Hashable, Sendable, Codable {
    /// The stroke is placed inside the original boundary.
    /// The outer edge of the stroke aligns with the original shape's outline.
    case inside

    /// The stroke is centered on the original boundary.
    /// Half of the stroke width extends inward, half extends outward.
    case centered

    /// The stroke is placed outside the original boundary.
    /// The inner edge of the stroke aligns with the original shape's outline.
    case outside
}

public extension Geometry2D {
    /// Converts the shape's outline into a filled stroke with the specified width.
    ///
    /// This operation replaces the filled shape with its stroked outline, creating
    /// a shape that follows the original boundary with the given thickness.
    ///
    /// ```swift
    /// Circle(diameter: 20)
    ///     .stroked(width: 2, alignment: .centered, style: .round)
    /// // Creates a ring with 2mm wall thickness, centered on the original circle
    ///
    /// Rectangle([30, 20])
    ///     .stroked(width: 1, alignment: .inside, style: .miter)
    /// // Creates a rectangular frame inside the original bounds
    /// ```
    ///
    /// - Parameters:
    ///   - width: The thickness of the stroke. Must be positive.
    ///   - alignment: How the stroke is positioned relative to the original boundary.
    ///   - style: The line join style for corners (e.g., `.round`, `.miter`, `.bevel`).
    /// - Returns: A new geometry representing the stroked outline.
    ///
    func stroked(width: Double, alignment: StrokeAlignment, style: LineJoinStyle) -> any Geometry2D {
        switch alignment {
        case .outside:
            return offset(amount: width, style: style)
                .subtracting { self }

        case .inside:
            return subtracting {
                offset(amount: -width, style: style)
            }

        case .centered:
            let halfWidth = width / 2
            return offset(amount: halfWidth, style: style)
                .subtracting {
                    offset(amount: -halfWidth, style: style)
                }
        }
    }

    /// Converts the shape's outline into a filled stroke, providing both the original and stroked geometries to a builder closure.
    ///
    /// This method creates a stroked version of the geometry and passes both the original
    /// and the stroke to the supplied builder closure. This enables further composition,
    /// such as combining the fill with its outline or constructing additional geometry.
    ///
    /// ```swift
    /// Circle(diameter: 20)
    ///     .stroked(width: 2, alignment: .outside, style: .round) { original, stroke in
    ///         original  // The filled circle
    ///         stroke    // The ring around it
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - width: The thickness of the stroke. Must be positive.
    ///   - alignment: How the stroke is positioned relative to the original boundary.
    ///   - style: The line join style for corners (e.g., `.round`, `.miter`, `.bevel`).
    ///   - reader: A closure that receives both the original geometry and the stroked geometry, and returns a new composed geometry.
    /// - Returns: The result of the builder closure.
    ///
    /// - SeeAlso: ``stroked(width:alignment:style:)``
    ///
    func stroked<Output: Dimensionality>(
        width: Double,
        alignment: StrokeAlignment,
        style: LineJoinStyle,
        @GeometryBuilder<Output> reader: @escaping @Sendable (_ original: any Geometry2D, _ stroked: any Geometry2D) -> Output.Geometry
    ) -> Output.Geometry {
        reader(self, stroked(width: width, alignment: alignment, style: style))
    }
}
