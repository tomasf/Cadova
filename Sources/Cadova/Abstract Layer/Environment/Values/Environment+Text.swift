import Foundation

internal extension EnvironmentValues {
    private static let key = Key("Cadova.TextAttributes")

    var textAttributes: TextAttributes {
        get { self[Self.key] as? TextAttributes ?? .init() }
        set { self[Self.key] = newValue }
    }
}

public extension EnvironmentValues {
    /// The name of the font family to use when rendering text.
    ///
    /// This value defines the typeface used in text rendering. It can be set alongside
    /// an optional font style (e.g., "Bold", "Italic") and a font file if needed.
    /// If not explicitly set, a default family such as "Arial" is used.
    ///
    /// Use `.withFont(...)` to assign a font family and style in modeling code.
    ///
    /// ```swift
    /// Text("Hello")
    ///   .withFont("Helvetica", style: "Bold")
    /// ```
    ///
    /// - SeeAlso: `fontStyle`, `fontFile`
    var fontFamily: String? { textAttributes.fontFace?.family }

    /// The style variant of the font, such as "Regular", "Bold", or "Italic".
    ///
    /// Used in conjunction with `fontFamily` to select the appropriate typeface variant.
    /// If no style is specified, the system may default to a regular variant.
    ///
    /// - SeeAlso: `fontFamily`
    var fontStyle: String? { textAttributes.fontFace?.style }

    /// An optional file URL pointing to a specific font file to use.
    ///
    /// This allows rendering with custom or embedded fonts, rather than relying solely
    /// on system-installed typefaces. The file should contain a valid TrueType or OpenType font.
    ///
    /// If not set, Cadova searches installed fonts to match the specified family and style.
    ///
    /// - SeeAlso: `fontFamily`, `fontStyle`
    var fontFile: URL? { textAttributes.fontFile }

    /// Sets the font attributes for text rendering in the environment.
    ///
    /// This method sets the font family, style, optional size, and optional font file to use for text rendering.
    /// These values affect how text is rendered in the geometry system.
    ///
    /// Use this when you want to explicitly assign multiple font-related settings at once.
    ///
    /// - Parameters:
    ///   - family: The name of the font family to use (e.g., "Helvetica").
    ///   - style: An optional style variant such as "Bold" or "Italic". Defaults to nil.
    ///   - size: An optional font size in points. If nil, the existing size is preserved.
    ///   - fontFile: An optional URL to a custom font file. If nil, the existing fontFile is preserved.
    mutating func setFont(family: String, style: String? = nil, size: Double? = nil, fontFile: URL? = nil) {
        textAttributes.fontFace = .init(family: family, style: style)
        textAttributes.fontSize = size ?? textAttributes.fontSize
        textAttributes.fontFile = fontFile ?? textAttributes.fontFile
    }

    /// The size of the font in points.
    ///
    /// Defines the height of the glyphs rendered in the final geometry.
    /// If not specified, a default size of 12 points is used.
    ///
    /// Use `.withFontSize(...)` to set this value on a geometry.
    ///
    /// ```swift
    /// Text("Large")
    ///   .withFontSize(24)
    /// ```
    var fontSize: Double? {
        get { textAttributes.fontSize }
        set { textAttributes.fontSize = newValue }
    }

    /// The horizontal alignment for multiline text rendering.
    ///
    /// Determines how each line of text is aligned horizontally within the text block.
    /// This affects rendering when line breaks (`\n`) are present in the text.
    ///
    /// Supported values include `.left`, `.center`, and `.right`.
    ///
    /// - SeeAlso: `verticalTextAlignment`
    var horizontalTextAlignment: HorizontalTextAlignment? {
        get { textAttributes.horizontalAlignment }
        set { textAttributes.horizontalAlignment = newValue }
    }

    /// The vertical alignment for multiline text rendering.
    ///
    /// Determines how multiple lines of text are vertically positioned relative to the origin.
    ///
    /// Values include:
    /// - `.firstBaseline`: Align the top line's baseline to the origin.
    /// - `.lastBaseline`: Align the bottom line's baseline.
    /// - `.top`, `.bottom`, `.center`: Align based on typographic metrics (ascenders and descenders).
    ///
    /// - SeeAlso: `horizontalTextAlignment`
    var verticalTextAlignment: VerticalTextAlignment? {
        get { textAttributes.verticalAlignment }
        set { textAttributes.verticalAlignment = newValue }
    }
}

public extension Geometry {
    /// Applies font settings to the geometry.
    ///
    /// This method sets the font family, optional style, size, and optional font file for text rendering.
    /// Use this to customize the appearance of text in your geometry.
    ///
    /// - Parameters:
    ///   - fontFamily: The name of the font family to use (e.g., "Helvetica").
    ///   - style: The optional font style (e.g., "Bold", "Italic").
    ///   - size: The optional font size in points. If not provided, the current or default size is used.
    ///   - fontFile: An optional URL pointing to a custom font file to use instead of a system font.
    /// - Returns: A new geometry with the font attributes applied.
    func withFont(_ fontFamily: String, style: String? = nil, size: Double? = nil, from fontFile: URL? = nil) -> D.Geometry {
        withEnvironment {
            $0.setFont(family: fontFamily, style: style, size: size, fontFile: fontFile)
        }
    }

    /// Sets the font size for text rendering.
    ///
    /// - Parameter fontSize: The font size in points.
    /// - Returns: A new geometry with the specified font size applied.
    func withFontSize(_ fontSize: Double) -> D.Geometry {
        withEnvironment {
            $0.fontSize = fontSize
        }
    }

    /// Sets the horizontal and vertical text alignment for multiline text.
    ///
    /// - Parameters:
    ///   - horizontal: The horizontal alignment (.left, .center, or .right). Optional.
    ///   - vertical: The vertical alignment (.firstBaseline, .lastBaseline, .top, .bottom, .center). Optional.
    /// - Returns: A new geometry with the specified text alignment settings.
    func withTextAlignment(horizontal: HorizontalTextAlignment? = nil, vertical: VerticalTextAlignment? = nil) -> D.Geometry {
        withEnvironment {
            if let horizontal {
                $0.horizontalTextAlignment = horizontal
            }
            if let vertical {
                $0.verticalTextAlignment = vertical
            }
        }
    }
}

public enum HorizontalTextAlignment: Sendable, Hashable, Codable {
    /// Aligns each line of text to the left edge.
    case left

    /// Centers each line of text horizontally.
    case center

    /// Aligns each line of text to the right edge.
    case right
}

public enum VerticalTextAlignment: Sendable, Hashable, Codable {
    /// Aligns the baseline of the first line of text to the origin.
    case firstBaseline

    /// Aligns the baseline of the last line of text to the origin.
    case lastBaseline

    /// Aligns the top of the text block to the origin.
    case top

    /// Aligns the vertical center of the text block to the origin.
    case center

    /// Aligns the bottom of the text block to the origin.
    case bottom
}
