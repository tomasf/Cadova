import Foundation

public struct Color: Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    /// Creates a new color with specified red, green, blue, and alpha components.
    ///
    /// - Parameters:
    ///   - red: The red component of the color, ranging from 0.0 to 1.0.
    ///   - green: The green component of the color, ranging from 0.0 to 1.0.
    ///   - blue: The blue component of the color, ranging from 0.0 to 1.0.
    ///   - alpha: The alpha (transparency) component of the color, ranging from 0.0 (fully transparent) to 1.0 (fully opaque). Default value is 1.0.
    ///
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Returns a copy of the color with a modified alpha (transparency) value.
    ///
    /// - Parameter a: The new alpha component, ranging from 0.0 (fully transparent) to 1.0 (fully opaque).
    /// - Returns: A new `Color` instance with the same red, green, and blue components but with the specified alpha value.
    ///
    public func withAlphaComponent(_ a: Double) -> Color {
        Color(red: red, green: green, blue: blue, alpha: a)
    }

    /// Returns the RGBA components as a tuple
    public var rgbaComponents: (red: Double, green: Double, blue: Double, alpha: Double) {
        (red: red, green: green, blue: blue, alpha: alpha)
    }
}

public extension Color {
    /// Blends the current color with another color by a specified amount.
    ///
    /// - Parameters:
    ///   - other: The other color to blend with.
    ///   - amount: The blending amount, between 0 (no blend, use current color) and 1 (full blend, use other color).
    /// - Returns: A new color that is the result of blending this color with the other color by the specified amount.
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
    enum Component {
        case red
        case green
        case blue

        case hue
        case saturation
        case brightness

        case alpha
    }

    func setting(_ component: Component, to value: Double) -> Color {
        let hsba = hsbaComponents

        return switch component {
        case .red: Color(red: value, green: green, blue: blue, alpha: alpha)
        case .green: Color(red: red, green: value, blue: blue, alpha: alpha)
        case .blue: Color(red: red, green: green, blue: value, alpha: alpha)
        case .alpha: Color(red: red, green: green, blue: blue, alpha: value)

        case .hue: Color(hue: value, saturation: hsba.saturation, brightness: hsba.brightness, alpha: alpha)
        case .saturation: Color(hue: hsba.hue, saturation: value, brightness: hsba.brightness, alpha: alpha)
        case .brightness: Color(hue: hsba.hue, saturation: hsba.saturation, brightness: value, alpha: alpha)
        }
    }
}
