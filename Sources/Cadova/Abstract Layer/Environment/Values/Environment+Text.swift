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

    /// An adjustment to the spacing between lines of text, in millimeters.
    ///
    /// This value modifies the default line height determined by the font's metrics.
    /// A positive value increases the space between lines, while a negative value
    /// decreases it.
    ///
    /// The default is `0`, meaning standard line spacing is used.
    ///
    /// ```swift
    /// Text("Line 1\nLine 2\nLine 3")
    ///     .withLineSpacing(2)  // Add 2mm between lines
    /// ```
    ///
    /// - SeeAlso: `fontSize`
    var lineSpacing: Double {
        get { textAttributes.lineSpacingAdjustment ?? 0 }
        set { textAttributes.lineSpacingAdjustment = newValue }
    }

    /// The tracking (letter-spacing) adjustment between characters, in millimeters.
    ///
    /// Tracking adjusts the uniform spacing between all characters in the text.
    /// A positive value increases spacing, while a negative value decreases it.
    ///
    /// The default is `0`, meaning standard character spacing is used.
    ///
    /// ```swift
    /// Text("SPACED")
    ///     .withTracking(1)  // Add 1mm between each character
    ///
    /// Text("TIGHT")
    ///     .withTracking(-0.5) // Reduce spacing by 0.5mm
    /// ```
    ///
    /// - SeeAlso: `fontSize`, `lineSpacing`
    var tracking: Double {
        get { textAttributes.tracking ?? 0 }
        set { textAttributes.tracking = newValue }
    }

    /// The font variations to apply to variable fonts.
    ///
    /// Font variations control axes like weight, width, and slant for variable fonts.
    /// If the font is not a variable font, variations are ignored.
    ///
    /// Use `.withFontVariations([...])` or specific modifiers like `.withFontWeight(_:)`
    /// to set variations on geometry.
    ///
    /// ```swift
    /// Text("Semibold")
    ///     .withFontWeight(600)
    ///
    /// Text("Condensed Bold")
    ///     .withFontVariations([.weight(700), .width(75)])
    /// ```
    ///
    /// - SeeAlso: `fontFamily`
    var fontVariations: [FontVariation] {
        get { textAttributes.fontVariations ?? [] }
        set { textAttributes.fontVariations = newValue }
    }
}
