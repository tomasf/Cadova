import Foundation

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
