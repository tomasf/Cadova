import Foundation
import freetype

/// A 2D shape that renders text using vector outlines derived from a font.
///
/// The `Text` shape lets you display strings using scalable vector geometry. It supports Unicode input, multiple lines via
/// newline characters, and customizable font attributes including typeface, style, and size. Text is converted to geometric
/// outlines suitable for modeling or extrusion, making it ideal for engraving, labeling, signage, or decorative features.
///
/// Text rendering is affected by environment values such as:
/// - `withFont(...)`: Sets the font family, size, and style.
/// - `withTextAlignment(...)`: Controls both horizontal and vertical alignment of the text block.
///
/// Example:
/// ```swift
/// Text("Hello\nCadova")
///   .withFont(family: "Helvetica", size: 12)
///   .withTextAlignment(horizontal: .center, vertical: .firstBaseline)
/// ```
///
public struct Text: Shape2D {
    private let content: String

    /// Creates a text shape from a string.
    ///
    /// - Parameter text: The string to render as vector-based geometry. Use `\n` for manual line breaks.
    ///
    public init(_ text: String) {
        self.content = text
    }

    public var body: any Geometry2D {
        @Environment var environment
        @Environment(\.textAttributes) var textAttributes
        @Environment(\.segmentation) var segmentation
        let attributes = textAttributes.applyingDefaults()

        CachedNode(name: "text", parameters: content, attributes, segmentation) { environment, context in
            let polygons = try attributes.render(text: content, in: environment)
            return .shape(.polygons(polygons, fillRule: .nonZero))
        }
    }
}
