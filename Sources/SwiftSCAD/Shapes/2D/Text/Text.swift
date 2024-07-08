import Foundation

/// Text as a 2D geometry
public struct Text: Geometry2D {
    let text: String

    /// Initializes a new text geometry with the specified text.
    ///
    /// This initializer creates a text geometry representation. To customize the appearance of the text, such as changing the font, alignment, or character spacing, use the following modifiers:
    /// - Use ``Geometry2D/usingFont(_:style:size:)`` to specify a font
    /// - Use ``Geometry2D/usingTextAlignment(horizontal:vertical:)`` to set the horizontal and/or vertical text alignment.
    /// - Use ``Geometry2D/usingCharacterSpacing(_:)`` to adjust the spacing between characters.
    ///
    /// - Parameter text: The text to be used in creating the text geometry.
    public init(_ text: String) {
        self.text = text
    }

    public func output(in environment: Environment) -> Output {
        return .init(invocation: environment.textAttributes.invocation(text: text), boundary: .empty)
    }

    /// An enumeration representing the horizontal alignment options for text geometry.
    ///
    /// Use these options with ``Geometry2D/usingTextAlignment(horizontal:vertical:)`` to set the horizontal alignment of your text geometry.
    public enum HorizontalAlignment: String, Sendable {
        /// Aligns the text to the left.
        case left
        /// Centers the text horizontally.
        case center
        /// Aligns the text to the right.
        case right
    }

    /// An enumeration representing the vertical alignment options for text geometry.
    ///
    /// - `top`: Aligns the text to the top.
    /// - `center`: Centers the text vertically.
    /// - `baseline`: Aligns the text to the baseline. The baseline is the line upon which most letters sit and below which descenders extend.
    /// - `bottom`: Aligns the text to the bottom.
    ///
    /// Use these options with ``Geometry2D/usingTextAlignment(horizontal:vertical:)`` to set the vertical alignment of your text geometry.
    public enum VerticalAlignment: String, Sendable {
        /// Aligns the text to the top.
        case top
        /// Centers the text vertically.
        case center
        /// Aligns the text to the baseline, the line upon which most letters sit and below which descenders extend.
        case baseline
        /// Aligns the text to the bottom.
        case bottom
    }
}

extension Environment.TextAttributes {
    func invocation(text: String) -> Invocation {
        let needsFontParameter = font != nil || fontStyle != nil
        let styleValue = fontStyle.map { ":style=\($0)" } ?? ""
        let fontValue = needsFontParameter ? (font ?? "") + styleValue : nil
        let size = (fontSize ?? 10.0) * 0.72

        return .init(name: "text", parameters: [
            "text": text,
            "font": fontValue,
            "size": size,
            "halign": horizontalAlignment?.rawValue,
            "valign": verticalAlignment?.rawValue,
            "spacing": characterSpacing
        ])
    }
}
