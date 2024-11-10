import Foundation

public struct Color: Sendable {
    private let red: Double
    private let green: Double
    private let blue: Double
    private let alpha: Double

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

internal extension Color {
    var moduleParameters: CodeFragment.Parameters {
        ["c": [red, green, blue, alpha]]
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
    /// Initializes a `Color` instance from hue, saturation, and brightness (HSB) values.
    ///
    /// - Parameters:
    ///   - hue: The hue of the color, ranging from 0.0 to 1.0.
    ///   - saturation: The saturation of the color, ranging from 0.0 to 1.0.
    ///   - brightness: The brightness of the color, ranging from 0.0 to 1.0.
    ///   - alpha: The alpha (transparency) component of the color, ranging from 0.0 (fully transparent) to 1.0 (fully opaque). Default value is 1.0.
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
    func adjusting(hue hDelta: Double = 0, saturation sDelta: Double = 0, brightness bDelta: Double = 0, alpha aDelta: Double = 0) -> Color {
        let hsba = self.hsbaComponents
        return Color(
            hue: (hsba.hue + hDelta).truncatingRemainder(dividingBy: 1),
            saturation: (hsba.saturation + sDelta).unitClamped,
            brightness: (hsba.brightness + bDelta).unitClamped,
            alpha: (hsba.alpha + aDelta).unitClamped
        )
    }
}

public extension Color {
    /// A very light blue, almost white.
    static let aliceBlue = Color(red: 0.941, green: 0.973, blue: 1.0)

    /// A warm off-white with hints of yellow and pink.
    static let antiqueWhite = Color(red: 0.980, green: 0.922, blue: 0.843)

    /// A bright cyan-blue, similar to the color of water.
    static let aqua = Color(red: 0.0, green: 1.0, blue: 1.0)

    /// A light sea green with a bright and refreshing look.
    static let aquamarine = Color(red: 0.498, green: 1.0, blue: 0.831)

    /// A very light blue, with a crisp and clear feel.
    static let azure = Color(red: 0.941, green: 1.0, blue: 1.0)

    /// A soft, warm beige with a muted, natural tone.
    static let beige = Color(red: 0.961, green: 0.961, blue: 0.863)

    /// A soft peachy color, reminiscent of pale skin tones.
    static let bisque = Color(red: 1.0, green: 0.894, blue: 0.769)

    /// Pure black with no hint of any other color.
    static let black = Color(red: 0.0, green: 0.0, blue: 0.0)

    /// A pale almond color with a creamy tone.
    static let blanchedAlmond = Color(red: 1.0, green: 0.922, blue: 0.804)

    /// A deep, rich blue.
    static let blue = Color(red: 0.0, green: 0.0, blue: 1.0)

    /// A rich violet with blue undertones.
    static let blueViolet = Color(red: 0.541, green: 0.169, blue: 0.886)

    /// A warm, earthy brown.
    static let brown = Color(red: 0.647, green: 0.165, blue: 0.165)

    /// A soft tan with hints of orange.
    static let burlyWood = Color(red: 0.871, green: 0.722, blue: 0.529)

    /// A muted blue with hints of green.
    static let cadetBlue = Color(red: 0.373, green: 0.620, blue: 0.627)

    /// A bright yellow-green, similar to chartreuse liqueur.
    static let chartreuse = Color(red: 0.498, green: 1.0, blue: 0.0)

    /// A warm brown with reddish undertones.
    static let chocolate = Color(red: 0.824, green: 0.412, blue: 0.118)

    /// A vibrant coral pink.
    static let coral = Color(red: 1.0, green: 0.498, blue: 0.314)

    /// A medium shade of blue with hints of lavender.
    static let cornflowerBlue = Color(red: 0.392, green: 0.584, blue: 0.929)

    /// A very pale yellow, similar to corn silk.
    static let cornsilk = Color(red: 1.0, green: 0.973, blue: 0.863)

    /// A deep red with hints of purple.
    static let crimson = Color(red: 0.863, green: 0.078, blue: 0.235)

    /// A bright and intense cyan-blue.
    static let cyan = Color(red: 0.0, green: 1.0, blue: 1.0)

    /// A very dark blue, close to black.
    static let darkBlue = Color(red: 0.0, green: 0.0, blue: 0.545)

    /// A dark cyan with a muted blue-green tone.
    static let darkCyan = Color(red: 0.0, green: 0.545, blue: 0.545)

    /// A rich, dark golden-yellow.
    static let darkGoldenrod = Color(red: 0.722, green: 0.525, blue: 0.043)

    /// A medium shade of gray.
    static let darkGray = Color(red: 0.663, green: 0.663, blue: 0.663)

    /// A dark green with deep, natural tones.
    static let darkGreen = Color(red: 0.0, green: 0.392, blue: 0.0)

    /// A muted yellowish-green, with hints of brown.
    static let darkKhaki = Color(red: 0.741, green: 0.718, blue: 0.420)

    /// A deep magenta with purple undertones.
    static let darkMagenta = Color(red: 0.545, green: 0.0, blue: 0.545)

    /// A muted green with olive tones.
    static let darkOliveGreen = Color(red: 0.333, green: 0.420, blue: 0.184)

    /// A vibrant, deep orange.
    static let darkOrange = Color(red: 1.0, green: 0.549, blue: 0.0)

    /// A medium purple with a warm tone.
    static let darkOrchid = Color(red: 0.600, green: 0.196, blue: 0.800)

    /// A deep, dark red.
    static let darkRed = Color(red: 0.545, green: 0.0, blue: 0.0)

    /// A soft salmon pink with a darker hue.
    static let darkSalmon = Color(red: 0.914, green: 0.588, blue: 0.478)

    /// A muted green with hints of gray.
    static let darkSeaGreen = Color(red: 0.561, green: 0.737, blue: 0.561)

    /// A dark slate blue with purple tones.
    static let darkSlateBlue = Color(red: 0.282, green: 0.239, blue: 0.545)

    /// A dark gray with greenish tones.
    static let darkSlateGray = Color(red: 0.184, green: 0.310, blue: 0.310)

    /// A vibrant turquoise blue.
    static let darkTurquoise = Color(red: 0.0, green: 0.808, blue: 0.820)

    /// A rich, deep violet.
    static let darkViolet = Color(red: 0.580, green: 0.0, blue: 0.827)

    /// A bold pink with a strong magenta tone.
    static let deepPink = Color(red: 1.0, green: 0.078, blue: 0.576)

    /// A bright blue that resembles a clear sky.
    static let deepSkyBlue = Color(red: 0.0, green: 0.749, blue: 1.0)

    /// A medium gray with a subtle tone.
    static let dimGray = Color(red: 0.412, green: 0.412, blue: 0.412)

    /// A bright, vivid blue.
    static let dodgerBlue = Color(red: 0.118, green: 0.565, blue: 1.0)

    /// A deep brick red with brown undertones.
    static let firebrick = Color(red: 0.698, green: 0.133, blue: 0.133)

    /// A warm off-white with a soft yellow tone.
    static let floralWhite = Color(red: 1.0, green: 0.980, blue: 0.941)

    /// A rich green with hints of blue.
    static let forestGreen = Color(red: 0.133, green: 0.545, blue: 0.133)

    /// A bright magenta pink.
    static let fuchsia = Color(red: 1.0, green: 0.0, blue: 1.0)

    /// A light gray with a subtle cool tone.
    static let gainsboro = Color(red: 0.863, green: 0.863, blue: 0.863)

    /// A very pale blue-gray.
    static let ghostWhite = Color(red: 0.973, green: 0.973, blue: 1.0)

    /// A bright, warm yellow with golden tones.
    static let gold = Color(red: 1.0, green: 0.843, blue: 0.0)

    /// A warm golden color with brown tones.
    static let goldenrod = Color(red: 0.855, green: 0.647, blue: 0.125)

    /// A neutral medium gray.
    static let gray = Color(red: 0.502, green: 0.502, blue: 0.502)

    /// A dark green with a medium tone.
    static let green = Color(red: 0.0, green: 0.502, blue: 0.0)

    /// A bright yellow-green with a vibrant look.
    static let greenYellow = Color(red: 0.678, green: 1.0, blue: 0.184)

    /// A very pale, soft green.
    static let honeydew = Color(red: 0.941, green: 1.0, blue: 0.941)

    /// A bright, warm pink.
    static let hotPink = Color(red: 1.0, green: 0.412, blue: 0.706)

    /// A warm red with brown undertones.
    static let indianRed = Color(red: 0.804, green: 0.361, blue: 0.361)

    /// A dark, cool purple with deep blue tones.
    static let indigo = Color(red: 0.294, green: 0.0, blue: 0.510)

    /// A warm off-white with a pale yellow tone.
    static let ivory = Color(red: 1.0, green: 1.0, blue: 0.941)

    /// A warm beige with a muted yellow tone.
    static let khaki = Color(red: 0.941, green: 0.902, blue: 0.549)

    /// A very light lavender color with a soft pastel feel.
    static let lavender = Color(red: 0.902, green: 0.902, blue: 0.980)

    /// A light pink with a soft blush tone.
    static let lavenderBlush = Color(red: 1.0, green: 0.941, blue: 0.961)

    /// A bright, vibrant green with a strong yellow tone.
    static let lawnGreen = Color(red: 0.486, green: 0.988, blue: 0.0)

    /// A pale yellow, similar to lemon cream.
    static let lemonChiffon = Color(red: 1.0, green: 0.980, blue: 0.804)

    /// A soft blue with hints of gray.
    static let lightBlue = Color(red: 0.678, green: 0.847, blue: 0.902)

    /// A soft red with a coral tone.
    static let lightCoral = Color(red: 0.941, green: 0.502, blue: 0.502)

    /// A very pale cyan with a soft, cool feel.
    static let lightCyan = Color(red: 0.878, green: 1.0, blue: 1.0)

    /// A pale yellow with a golden tone.
    static let lightGoldenrodYellow = Color(red: 0.980, green: 0.980, blue: 0.824)

    /// A light gray with a soft, neutral feel.
    static let lightGray = Color(red: 0.827, green: 0.827, blue: 0.827)

    /// A soft green with a bright tone.
    static let lightGreen = Color(red: 0.565, green: 0.933, blue: 0.565)

    /// A pale pink with hints of peach.
    static let lightPink = Color(red: 1.0, green: 0.714, blue: 0.757)

    /// A soft, light salmon color.
    static let lightSalmon = Color(red: 1.0, green: 0.627, blue: 0.478)

    /// A medium green-blue color.
    static let lightSeaGreen = Color(red: 0.125, green: 0.698, blue: 0.667)

    /// A soft blue with a light sky-like tone.
    static let lightSkyBlue = Color(red: 0.529, green: 0.808, blue: 0.980)

    /// A soft gray with hints of blue.
    static let lightSlateGray = Color(red: 0.467, green: 0.533, blue: 0.600)

    /// A soft blue-gray with a slightly metallic feel.
    static let lightSteelBlue = Color(red: 0.690, green: 0.769, blue: 0.871)

    /// A very pale yellow with a warm tone.
    static let lightYellow = Color(red: 1.0, green: 1.0, blue: 0.878)

    /// A bright and vivid green.
    static let lime = Color(red: 0.0, green: 1.0, blue: 0.0)

    /// A medium green with yellow undertones.
    static let limeGreen = Color(red: 0.196, green: 0.804, blue: 0.196)

    /// A warm off-white with pale beige tones.
    static let linen = Color(red: 0.980, green: 0.941, blue: 0.902)

    /// A vibrant magenta-pink.
    static let magenta = Color(red: 1.0, green: 0.0, blue: 1.0)

    /// A deep, warm brownish-red.
    static let maroon = Color(red: 0.502, green: 0.0, blue: 0.0)

    /// A medium aquamarine with a soft, muted blue-green tone.
    static let mediumAquamarine = Color(red: 0.400, green: 0.804, blue: 0.667)

    /// A strong blue with a slightly muted tone.
    static let mediumBlue = Color(red: 0.0, green: 0.0, blue: 0.804)

    /// A warm orchid color with pink and purple tones.
    static let mediumOrchid = Color(red: 0.729, green: 0.333, blue: 0.827)

    /// A medium purple with a cool, muted tone.
    static let mediumPurple = Color(red: 0.576, green: 0.439, blue: 0.859)

    /// A soft, medium green with hints of blue.
    static let mediumSeaGreen = Color(red: 0.235, green: 0.702, blue: 0.443)

    /// A medium blue with slight violet tones.
    static let mediumSlateBlue = Color(red: 0.482, green: 0.408, blue: 0.933)

    /// A bright spring green with a vivid, fresh tone.
    static let mediumSpringGreen = Color(red: 0.0, green: 0.980, blue: 0.604)

    /// A light turquoise with bright blue-green tones.
    static let mediumTurquoise = Color(red: 0.282, green: 0.820, blue: 0.800)

    /// A rich magenta with red undertones.
    static let mediumVioletRed = Color(red: 0.780, green: 0.082, blue: 0.522)

    /// A very dark blue with a cool, muted tone.
    static let midnightBlue = Color(red: 0.098, green: 0.098, blue: 0.439)

    /// A very pale mint green.
    static let mintCream = Color(red: 0.961, green: 1.0, blue: 0.980)

    /// A pale rose with soft pink tones.
    static let mistyRose = Color(red: 1.0, green: 0.894, blue: 0.882)

    /// A pale orange with warm, creamy tones.
    static let moccasin = Color(red: 1.0, green: 0.894, blue: 0.710)

    /// A warm, creamy off-white with pale orange tones.
    static let navajoWhite = Color(red: 1.0, green: 0.871, blue: 0.678)

    /// A dark, muted blue with hints of purple.
    static let navy = Color(red: 0.0, green: 0.0, blue: 0.502)

    /// A warm beige with hints of pale peach.
    static let oldLace = Color(red: 0.992, green: 0.961, blue: 0.902)

    /// A muted green with brown undertones.
    static let olive = Color(red: 0.502, green: 0.502, blue: 0.0)

    /// A dark olive green with yellow undertones.
    static let oliveDrab = Color(red: 0.420, green: 0.557, blue: 0.137)

    /// A bright orange with a warm, vibrant tone.
    static let orange = Color(red: 1.0, green: 0.647, blue: 0.0)

    /// A rich orange with red undertones.
    static let orangeRed = Color(red: 1.0, green: 0.271, blue: 0.0)

    /// A warm orchid color with strong pink undertones.
    static let orchid = Color(red: 0.855, green: 0.439, blue: 0.839)

    /// A light, muted yellow with a golden undertone.
    static let paleGoldenrod = Color(red: 0.933, green: 0.910, blue: 0.667)

    /// A soft green with a pale tone.
    static let paleGreen = Color(red: 0.596, green: 0.984, blue: 0.596)

    /// A light, soft turquoise with a pale tone.
    static let paleTurquoise = Color(red: 0.686, green: 0.933, blue: 0.933)

    /// A soft violet-red with pale undertones.
    static let paleVioletRed = Color(red: 0.859, green: 0.439, blue: 0.576)

    /// A warm, creamy off-white with a hint of orange.
    static let papayaWhip = Color(red: 1.0, green: 0.937, blue: 0.835)

    /// A soft peach with warm undertones.
    static let peachPuff = Color(red: 1.0, green: 0.855, blue: 0.725)

    /// A warm brown with reddish undertones.
    static let peru = Color(red: 0.804, green: 0.522, blue: 0.247)

    /// A light, warm pink.
    static let pink = Color(red: 1.0, green: 0.753, blue: 0.796)

    /// A soft lavender with a cool tone.
    static let plum = Color(red: 0.867, green: 0.627, blue: 0.867)

    /// A soft, muted blue with a hint of gray.
    static let powderBlue = Color(red: 0.690, green: 0.878, blue: 0.902)

    /// A deep purple with a dark tone.
    static let purple = Color(red: 0.502, green: 0.0, blue: 0.502)

    /// A muted purple with a hint of gray.
    static let rebeccaPurple = Color(red: 0.400, green: 0.200, blue: 0.600)

    /// A bright, vivid red.
    static let red = Color(red: 1.0, green: 0.0, blue: 0.0)

    /// A warm, muted brown with pink undertones.
    static let rosyBrown = Color(red: 0.737, green: 0.561, blue: 0.561)

    /// A vibrant royal blue with a deep, rich tone.
    static let royalBlue = Color(red: 0.255, green: 0.412, blue: 0.882)

    /// A deep, warm brown.
    static let saddleBrown = Color(red: 0.545, green: 0.271, blue: 0.075)

    /// A warm, light salmon color.
    static let salmon = Color(red: 0.980, green: 0.502, blue: 0.447)

    /// A light brown with hints of orange.
    static let sandyBrown = Color(red: 0.957, green: 0.643, blue: 0.376)

    /// A medium green with a muted tone.
    static let seaGreen = Color(red: 0.180, green: 0.545, blue: 0.341)

    /// A pale off-white with a warm tone.
    static let seashell = Color(red: 1.0, green: 0.961, blue: 0.933)

    /// A rich brown with a slightly reddish tone.
    static let sienna = Color(red: 0.627, green: 0.322, blue: 0.176)

    /// A soft, metallic silver tone.
    static let silver = Color(red: 0.753, green: 0.753, blue: 0.753)

    /// A medium sky blue with a soft tone.
    static let skyBlue = Color(red: 0.529, green: 0.808, blue: 0.922)

    /// A medium slate blue with a muted tone.
    static let slateBlue = Color(red: 0.416, green: 0.353, blue: 0.804)

    /// A cool, muted gray with a hint of blue.
    static let slateGray = Color(red: 0.439, green: 0.502, blue: 0.565)

    /// A very pale, snow-like white.
    static let snow = Color(red: 1.0, green: 0.980, blue: 0.980)

    /// A bright, vibrant green with a slight yellow tint.
    static let springGreen = Color(red: 0.0, green: 1.0, blue: 0.498)

    /// A medium blue-gray with a cool tone.
    static let steelBlue = Color(red: 0.275, green: 0.510, blue: 0.706)

    /// A warm tan with a soft brown tone.
    static let tan = Color(red: 0.824, green: 0.706, blue: 0.549)

    /// A medium teal with a balanced green-blue tone.
    static let teal = Color(red: 0.0, green: 0.502, blue: 0.502)

    /// A soft purple with a warm, muted tone.
    static let thistle = Color(red: 0.847, green: 0.749, blue: 0.847)

    /// A warm tomato red with a hint of orange.
    static let tomato = Color(red: 1.0, green: 0.388, blue: 0.278)

    /// A light turquoise with bright, fresh tones.
    static let turquoise = Color(red: 0.251, green: 0.878, blue: 0.816)

    /// A soft violet with a light, warm tone.
    static let violet = Color(red: 0.933, green: 0.510, blue: 0.933)

    /// A pale wheat color with a warm tone.
    static let wheat = Color(red: 0.961, green: 0.871, blue: 0.702)

    /// A pure white.
    static let white = Color(red: 1.0, green: 1.0, blue: 1.0)

    /// A soft, off-white with a smoky tone.
    static let whiteSmoke = Color(red: 0.961, green: 0.961, blue: 0.961)

    /// A bright, primary yellow.
    static let yellow = Color(red: 1.0, green: 1.0, blue: 0.0)

    /// A medium yellow-green with a soft tone.
    static let yellowGreen = Color(red: 0.604, green: 0.804, blue: 0.196)

    /// A fully transparent color.
    static let transparent = black.withAlphaComponent(0)
}
