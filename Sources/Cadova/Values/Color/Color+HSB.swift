import Foundation

public extension Color {
    var hue: Double { hsbaComponents.hue }
    var saturation: Double { hsbaComponents.saturation }
    var brightness: Double { hsbaComponents.brightness }

    /// Initializes a `Color` instance from hue, saturation, and brightness (HSB) values.
    ///
    /// - Parameters:
    ///   - hue: The hue of the color, ranging from 0.0 to 1.0.
    ///   - saturation: The saturation of the color, ranging from 0.0 to 1.0.
    ///   - brightness: The brightness of the color, ranging from 0.0 to 1.0.
    ///   - alpha: The alpha (transparency) component of the color, ranging from 0.0 (fully transparent) to 1.0 (fully
    ///     opaque). Default value is 1.0.
    ///
    init(hue: Double, saturation: Double, brightness: Double, alpha: Double = 1.0) {
        let h = hue * 6.0 // Scale hue to be in the range [0, 6)
        let i = floor(h) // Hue segment (0 to 5)
        let f = h - i // Fractional part of hue, used for interpolation

        let p = brightness * (1 - saturation)
        let q = brightness * (1 - saturation * f)
        let t = brightness * (1 - saturation * (1 - f))

        switch Int(i) % 6 {
        case 0: self.init(red: brightness, green: t, blue: p, alpha: alpha)
        case 1: self.init(red: q, green: brightness, blue: p, alpha: alpha)
        case 2: self.init(red: p, green: brightness, blue: t, alpha: alpha)
        case 3: self.init(red: p, green: q, blue: brightness, alpha: alpha)
        case 4: self.init(red: t, green: p, blue: brightness, alpha: alpha)
        case 5: self.init(red: brightness, green: p, blue: q, alpha: alpha)
        default: self.init(red: brightness, green: brightness, blue: brightness, alpha: alpha)
        }
    }

    /// Returns the HSBA components as a tuple
    var hsbaComponents: (hue: Double, saturation: Double, brightness: Double, alpha: Double) {
        let maxComponent = max(red, green, blue)
        let minComponent = min(red, green, blue)
        let delta = maxComponent - minComponent

        // Calculate brightness
        let brightness = maxComponent

        // Calculate saturation
        let saturation = maxComponent == 0 ? 0 : delta / maxComponent

        // Calculate hue
        let hue: Double
        if delta == 0 {
            hue = 0
        } else if maxComponent == red {
            hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6) / 6
        } else if maxComponent == green {
            hue = ((blue - red) / delta + 2) / 6
        } else { // maxComponent == blue
            hue = ((red - green) / delta + 4) / 6
        }

        // Ensure hue is in the range [0, 1]
        let normalizedHue = hue < 0 ? hue + 1 : hue
        return (hue: normalizedHue, saturation: saturation, brightness: brightness, alpha: alpha)
    }

    /// Adjusts the HSBA values by the given delta values and returns a new `Color`.
    ///
    /// - Parameters:
    ///   - hDelta: The amount to adjust the hue by, in the range [-1, 1].
    ///   - sDelta: The amount to adjust the saturation by, in the range [-1, 1].
    ///   - bDelta: The amount to adjust the brightness by, in the range [-1, 1].
    ///   - aDelta: The amount to adjust the alpha by, in the range [-1, 1].
    /// - Returns: A new `Color` instance with the adjusted HSBA values.
    func adjusting(
        hue hDelta: Double = 0,
        saturation sDelta: Double = 0,
        brightness bDelta: Double = 0,
        alpha aDelta: Double = 0
    ) -> Color {
        let hsba = self.hsbaComponents
        return Color(
            hue: (hsba.hue + hDelta).truncatingRemainder(dividingBy: 1),
            saturation: (hsba.saturation + sDelta).unitClamped,
            brightness: (hsba.brightness + bDelta).unitClamped,
            alpha: (hsba.alpha + aDelta).unitClamped
        )
    }
}
