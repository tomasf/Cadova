import Foundation

/// An RGBA color represented with Double components in the range 0.0–1.0.
///
public struct Color: Hashable, Sendable, Codable {
    /// The red component of the color, in the range 0.0–1.0.
    public let red: Double
    /// The green component of the color, in the range 0.0–1.0.
    public let green: Double
    /// The blue component of the color, in the range 0.0–1.0.
    public let blue: Double
    /// The alpha (opacity) component of the color, in the range 0.0–1.0.
    public let alpha: Double

    /// Creates a new color with specified red, green, blue, and alpha components.
    ///
    /// - Parameters:
    ///   - red: The red component of the color, ranging from 0.0 to 1.0.
    ///   - green: The green component of the color, ranging from 0.0 to 1.0.
    ///   - blue: The blue component of the color, ranging from 0.0 to 1.0.
    ///   - alpha: The alpha (transparency) component of the color, ranging from 0.0 (fully transparent) to 1.0 (fully
    ///     opaque). Default value is 1.0.
    ///
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Creates a new color with specified red, green, blue, and alpha components.
    ///
    /// - Parameters:
    ///   - red: The red component, 0.0–1.0.
    ///   - green: The green component, 0.0–1.0.
    ///   - blue: The blue component, 0.0–1.0.
    ///   - alpha: The alpha component, 0.0–1.0. Defaults to 1.0.
    ///
    public init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1.0) {
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Creates a grayscale color with the same value for red, green, and blue.
    ///
    /// - Parameters:
    ///   - brightness: The brightness value applied to red, green, and blue, 0.0–1.0.
    ///   - alpha: The alpha component, 0.0–1.0. Defaults to 1.0.
    ///
    public init(brightness: Double, alpha: Double = 1.0) {
        self.init(red: brightness, green: brightness, blue: brightness, alpha: alpha)
    }

    /// Returns the RGBA components as a tuple.
    ///
    /// - Returns: A tuple `(red, green, blue, alpha)` with each component in 0.0–1.0.
    ///
    public var rgbaComponents: (red: Double, green: Double, blue: Double, alpha: Double) {
        (red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Creates a color from a hexadecimal string.
    ///
    /// The string must contain either 6 or 8 hexadecimal digits:
    /// - 6 digits represent RGB (red, green, blue), with alpha assumed to be 1.0.
    /// - 8 digits represent RGBA (red, green, blue, alpha).
    ///
    /// Each pair of hex digits corresponds to a component in the range 00–FF, which is converted to a
    /// Double in the range 0.0–1.0. The initializer ignores any non-hex prefix characters (such as “#”)
    /// by extracting only the hex digits.
    ///
    /// - Parameter hex: A string containing 6 or 8 hexadecimal digits (optionally with a leading “#”).
    ///
    public init(hex: String) {
        let values = hex.compactMap(\.hexDigitValue)
        guard values.count == 6 || values.count == 8 else {
            fatalError("Invalid hex color code")
        }

        self.init(
            Double(values[0] * 16 + values[1]) / 255.0,
            Double(values[2] * 16 + values[3]) / 255.0,
            Double(values[4] * 16 + values[5]) / 255.0,
            Double(values.count == 8 ? values[6] * 16 + values[7] : 255) / 255.0
        )
    }
}

public extension Color {
    /// Blends the current color with another color by a specified amount.
    ///
    /// - Parameters:
    ///   - other: The other color to blend with.
    ///   - amount: The blending amount, between 0 (no blend, use current color) and 1 (full blend, use other color).
    /// - Returns: A new color that is the result of blending this color with the other color by the specified amount.
    /// 
    func mixed(with other: Color, amount: Double) -> Color {
        let clampedAmount = amount.unitClamped
        let inverseAmount = 1 - clampedAmount

        return Color(
            red: (red * inverseAmount) + (other.red * clampedAmount),
            green: (green * inverseAmount) + (other.green * clampedAmount),
            blue: (blue * inverseAmount) + (other.blue * clampedAmount),
            alpha: (alpha * inverseAmount) + (other.alpha * clampedAmount)
        )
    }
}

public extension Color {
    /// Returns a copy of this color with its alpha component replaced.
    ///
    /// - Parameter alpha: The new alpha component, 0.0–1.0.
    /// - Returns: A color with the same RGB components and the specified alpha.
    ///
    func with(alpha: Double) -> Self {
        Color(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Returns a copy of this color with specified components replaced.
    ///
    /// Any parameter left as `nil` retains its current value.
    ///
    /// - Parameters:
    ///   - red: Optional new red component, 0.0–1.0.
    ///   - green: Optional new green component, 0.0–1.0.
    ///   - blue: Optional new blue component, 0.0–1.0.
    ///   - alpha: Optional new alpha component, 0.0–1.0.
    /// - Returns: A color with the provided components replaced.
    ///
    func with(red: Double? = nil, green: Double? = nil, blue: Double? = nil, alpha: Double? = nil) -> Self {
        Color(red: red ?? self.red, green: green ?? self.green, blue: blue ?? self.blue, alpha: alpha ?? self.alpha)
    }

    /// Returns a copy of this color using HSBA to replace components.
    ///
    /// The color is converted to HSBA, the provided values are substituted, and the result is converted back to RGBA.
    /// Any parameter left as `nil` retains its current value.
    ///
    /// - Parameters:
    ///   - hue: Optional new hue component, typically in 0.0–1.0.
    ///   - saturation: Optional new saturation component, 0.0–1.0.
    ///   - brightness: Optional new brightness component, 0.0–1.0.
    ///   - alpha: Optional new alpha component, 0.0–1.0.
    /// - Returns: A color with the provided HSBA components replaced.
    ///
    func with(hue: Double? = nil, saturation: Double? = nil, brightness: Double? = nil, alpha: Double? = nil) -> Self {
        let hsba = hsbaComponents
        return Color(hue: hue ?? hsba.hue, saturation: saturation ?? hsba.saturation, brightness: brightness ?? hsba.brightness, alpha: alpha ?? hsba.alpha)
    }
}
