import Foundation
internal import Apus

/// A variation axis value to apply to a variable font.
///
/// Variable fonts allow continuous variation along design axes such as weight,
/// width, and slant. Use `FontVariation` to specify custom axis values when
/// rendering text.
///
/// ```swift
/// Text("Semibold Condensed")
///     .withFontVariations([.weight(600), .width(85)])
/// ```
///
/// Common axes have convenience factory methods:
/// - ``weight(_:)`` - Font weight (typically 100-900)
/// - ``width(_:)`` - Font width as percentage (typically 50-200)
/// - ``slant(_:)`` - Slant angle in degrees
/// - ``italic(_:)`` - Italic axis (0 = roman, 1 = italic)
/// - ``opticalSize(_:)`` - Optical size in points
///
/// For custom axes, use ``init(tag:value:)``:
/// ```swift
/// FontVariation(tag: "GRAD", value: 50)  // Grade axis
/// ```
///
public struct FontVariation: Sendable, Hashable, Codable {
    /// The 4-character OpenType axis tag (e.g., "wght", "wdth").
    public let tag: String

    /// The axis value in design space coordinates.
    public let value: Double

    /// Creates a variation with a custom axis tag and value.
    ///
    /// - Parameters:
    ///   - tag: A 4-character OpenType axis tag.
    ///   - value: The axis value in design space coordinates.
    public init(tag: String, value: Double) {
        precondition(tag.count == 4, "Axis tag must be exactly 4 characters")
        self.tag = tag
        self.value = value
    }

    // MARK: - Common Axes

    /// Weight axis (wght). Common range: 100-900.
    ///
    /// Standard weight values:
    /// - 100: Thin
    /// - 200: Extra Light
    /// - 300: Light
    /// - 400: Regular
    /// - 500: Medium
    /// - 600: Semibold
    /// - 700: Bold
    /// - 800: Extra Bold
    /// - 900: Black
    ///
    public static func weight(_ value: Double) -> FontVariation {
        FontVariation(tag: Apus.FontVariation.weightTag, value: value)
    }

    /// Width axis (wdth). Common range: 50-200, where 100 is normal.
    ///
    /// Values below 100 produce condensed text, values above produce expanded text.
    ///
    public static func width(_ value: Double) -> FontVariation {
        FontVariation(tag: Apus.FontVariation.widthTag, value: value)
    }

    /// Slant axis (slnt). Typically in degrees, negative for rightward slant.
    ///
    /// Common range: -12 to 0, where 0 is upright.
    ///
    public static func slant(_ value: Double) -> FontVariation {
        FontVariation(tag: Apus.FontVariation.slantTag, value: value)
    }

    /// Italic axis (ital). Typically 0 (roman) or 1 (italic).
    ///
    public static func italic(_ value: Double) -> FontVariation {
        FontVariation(tag: Apus.FontVariation.italicTag, value: value)
    }

    /// Optical size axis (opsz). Typically matches the point size.
    ///
    /// Fonts with optical size axes adjust their design based on the
    /// intended display size.
    ///
    public static func opticalSize(_ value: Double) -> FontVariation {
        FontVariation(tag: Apus.FontVariation.opticalSizeTag, value: value)
    }
}

internal extension Array where Element == FontVariation {
    /// Returns a new array with the given variation replacing any existing variation for the same axis.
    func replacingVariation(_ variation: FontVariation) -> [FontVariation] {
        var result = self.filter { $0.tag != variation.tag }
        result.append(variation)
        return result
    }
}
