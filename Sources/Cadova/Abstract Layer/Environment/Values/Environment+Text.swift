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

    /// Adjusts the spacing between lines of text.
    ///
    /// This modifier changes the vertical distance between lines in multiline text.
    /// A positive value increases spacing, while a negative value decreases it.
    ///
    /// ```swift
    /// Text("Hello\nWorld")
    ///     .withLineSpacing(5)  // Add 5mm between lines
    ///
    /// Text("Compact\nText")
    ///     .withLineSpacing(-2) // Reduce spacing by 2mm
    /// ```
    ///
    /// - Parameter adjustment: The amount to adjust line spacing, in millimeters.
    ///   Positive values increase spacing, negative values decrease it.
    /// - Returns: A new geometry with the adjusted line spacing.
    func withLineSpacing(_ adjustment: Double) -> D.Geometry {
        withEnvironment {
            $0.lineSpacing = adjustment
        }
    }

    /// Adjusts the tracking (letter-spacing) between characters in text.
    ///
    /// This modifier changes the uniform spacing between all characters.
    /// A positive value increases spacing, while a negative value decreases it.
    ///
    /// ```swift
    /// Text("SPACED")
    ///     .withTracking(1)  // Add 1mm between each character
    ///
    /// Text("TIGHT")
    ///     .withTracking(-0.5) // Reduce spacing by 0.5mm
    /// ```
    ///
    /// - Parameter adjustment: The amount to adjust character spacing, in millimeters.
    ///   Positive values increase spacing, negative values decrease it.
    /// - Returns: A new geometry with the adjusted tracking.
    func withTracking(_ adjustment: Double) -> D.Geometry {
        withEnvironment {
            $0.tracking = adjustment
        }
    }

    /// Applies font variations to variable fonts for text rendering.
    ///
    /// This replaces any existing font variations. For variable fonts, these
    /// variations control design axes like weight, width, slant, etc.
    ///
    /// ```swift
    /// Text("Custom Style")
    ///     .withFontVariations([.weight(600), .width(85), .slant(-6)])
    /// ```
    ///
    /// - Parameter variations: The variations to apply.
    /// - Returns: A new geometry with the specified font variations.
    func withFontVariations(_ variations: [FontVariation]) -> D.Geometry {
        withEnvironment {
            $0.fontVariations = variations
        }
    }

    /// Sets common font variation axes for variable fonts.
    ///
    /// This modifier updates the specified axes while preserving other existing variations.
    /// Only non-nil parameters are applied.
    ///
    /// ```swift
    /// Text("Bold Condensed")
    ///     .withFontVariations(weight: 700, width: 75)
    ///
    /// Text("Oblique")
    ///     .withFontVariations(slant: -12)
    /// ```
    ///
    /// - Parameters:
    ///   - weight: The weight value (typically 100-900). Common values: 100 Thin, 300 Light,
    ///     400 Regular, 500 Medium, 600 Semibold, 700 Bold, 900 Black.
    ///   - width: The width as a percentage (typically 50-200). 100 is normal,
    ///     below 100 is condensed, above 100 is expanded.
    ///   - slant: The slant angle in degrees (typically -12 to 0). Negative values
    ///     produce a rightward slant.
    ///   - italic: The italic axis value (typically 0 for roman, 1 for italic).
    ///   - opticalSize: The optical size in points. Fonts with this axis adjust
    ///     their design based on the intended display size.
    /// - Returns: A new geometry with the specified font variations.
    func withFontVariations(
        weight: Double? = nil,
        width: Double? = nil,
        slant: Double? = nil,
        italic: Double? = nil,
        opticalSize: Double? = nil
    ) -> D.Geometry {
        withEnvironment {
            var variations = $0.fontVariations
            if let weight {
                variations = variations.replacingVariation(.weight(weight))
            }
            if let width {
                variations = variations.replacingVariation(.width(width))
            }
            if let slant {
                variations = variations.replacingVariation(.slant(slant))
            }
            if let italic {
                variations = variations.replacingVariation(.italic(italic))
            }
            if let opticalSize {
                variations = variations.replacingVariation(.opticalSize(opticalSize))
            }
            $0.fontVariations = variations
        }
    }
}

/// Horizontal alignment options for text relative to the origin.
///
/// Use with ``Geometry/withTextAlignment(horizontal:vertical:)`` to control how
/// text is positioned horizontally relative to the X origin.
///
public enum HorizontalTextAlignment: Sendable, Hashable, Codable {
    /// Places the left (minimum X) edge of the text at the origin.
    case left

    /// Centers the text horizontally (center X) on the origin.
    case center

    /// Places the right edge (maximum X) of the text at the origin.
    case right
}

/// Vertical alignment options for text relative to the origin.
///
/// Use with ``Geometry/withTextAlignment(horizontal:vertical:)`` to control how
/// text is positioned vertically relative to the Y origin.
///
public enum VerticalTextAlignment: Sendable, Hashable, Codable {
    /// Places the baseline of the first line at the origin.
    case firstBaseline

    /// Places the baseline of the last line at the origin.
    case lastBaseline

    /// Places the top of the text (ascender) at the origin.
    case top

    /// Centers the text vertically on the origin.
    case center

    /// Places the bottom of the text (descender) at the origin.
    case bottom
}
