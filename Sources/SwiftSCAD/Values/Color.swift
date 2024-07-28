import Foundation

public struct Color: Sendable {
    private let value: Value

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        value = .components(red: red, green: green, blue: blue, alpha: alpha)
    }

    func withAlphaComponent(_ alpha: Double) -> Color {
        switch value {
        case .components (let red, let green, let blue, _):
            Color(red: red, green: green, blue: blue, alpha: alpha)
        case .named (let name, _):
            Color(name: name, alpha: alpha)
        }
    }
}

internal extension Color {
    enum Value {
        case components (red: Double, green: Double, blue: Double, alpha: Double)
        case named (String, alpha: Double)

        var parameters: Invocation.Parameters {
            switch self {
            case .components (let red, let green, let blue, let alpha):
                ["c": [red, green, blue, alpha]]
            case .named (let name, let alpha):
                ["c": name, "alpha": alpha]
            }
        }
    }

    init(name: String, alpha: Double = 1.0) {
        value = .named(name, alpha: alpha)
    }

    var invocation: Invocation {
        Invocation(name: "color", parameters: value.parameters)
    }
}

public extension Color {
    static let lavender = Color(name: "lavender")
    static let thistle = Color(name: "thistle")
    static let plum = Color(name: "plum")
    static let violet = Color(name: "violet")
    static let orchid = Color(name: "orchid")
    static let fuchsia = Color(name: "fuchsia")
    static let magenta = Color(name: "magenta")
    static let mediumOrchid = Color(name: "mediumOrchid")
    static let mediumPurple = Color(name: "mediumPurple")
    static let blueViolet = Color(name: "blueViolet")
    static let darkViolet = Color(name: "darkViolet")
    static let darkOrchid = Color(name: "darkOrchid")
    static let darkMagenta = Color(name: "darkMagenta")
    static let purple = Color(name: "purple")
    static let indigo = Color(name: "indigo")
    static let darkSlateBlue = Color(name: "darkSlateBlue")
    static let slateBlue = Color(name: "slateBlue")
    static let mediumSlateBlue = Color(name: "mediumSlateBlue")
    static let pink = Color(name: "pink")
    static let lightPink = Color(name: "lightPink")
    static let hotPink = Color(name: "hotPink")
    static let deepPink = Color(name: "deepPink")
    static let mediumVioletRed = Color(name: "mediumVioletRed")
    static let paleVioletRed = Color(name: "paleVioletRed")
    static let aqua = Color(name: "aqua")
    static let cyan = Color(name: "cyan")
    static let lightCyan = Color(name: "lightCyan")
    static let paleTurquoise = Color(name: "paleTurquoise")
    static let aquamarine = Color(name: "aquamarine")
    static let turquoise = Color(name: "turquoise")
    static let mediumTurquoise = Color(name: "mediumTurquoise")
    static let darkTurquoise = Color(name: "darkTurquoise")
    static let cadetBlue = Color(name: "cadetBlue")
    static let steelBlue = Color(name: "steelBlue")
    static let lightSteelBlue = Color(name: "lightSteelBlue")
    static let powderBlue = Color(name: "powderBlue")
    static let lightBlue = Color(name: "lightBlue")
    static let skyBlue = Color(name: "skyBlue")
    static let lightSkyBlue = Color(name: "lightSkyBlue")
    static let deepSkyBlue = Color(name: "deepSkyBlue")
    static let dodgerBlue = Color(name: "dodgerBlue")
    static let cornflowerBlue = Color(name: "cornflowerBlue")
    static let royalBlue = Color(name: "royalBlue")
    static let blue = Color(name: "blue")
    static let mediumBlue = Color(name: "mediumBlue")
    static let darkBlue = Color(name: "darkBlue")
    static let navy = Color(name: "navy")
    static let midnightBlue = Color(name: "midnightBlue")
    static let indianRed = Color(name: "indianRed")
    static let lightCoral = Color(name: "lightCoral")
    static let salmon = Color(name: "salmon")
    static let darkSalmon = Color(name: "darkSalmon")
    static let lightSalmon = Color(name: "lightSalmon")
    static let red = Color(name: "red")
    static let crimson = Color(name: "crimson")
    static let fireBrick = Color(name: "fireBrick")
    static let darkRed = Color(name: "darkRed")
    static let greenYellow = Color(name: "greenYellow")
    static let chartreuse = Color(name: "chartreuse")
    static let lawnGreen = Color(name: "lawnGreen")
    static let lime = Color(name: "lime")
    static let limeGreen = Color(name: "limeGreen")
    static let paleGreen = Color(name: "paleGreen")
    static let lightGreen = Color(name: "lightGreen")
    static let mediumSpringGreen = Color(name: "mediumSpringGreen")
    static let springGreen = Color(name: "springGreen")
    static let mediumSeaGreen = Color(name: "mediumSeaGreen")
    static let seaGreen = Color(name: "seaGreen")
    static let forestGreen = Color(name: "forestGreen")
    static let green = Color(name: "green")
    static let darkGreen = Color(name: "darkGreen")
    static let yellowGreen = Color(name: "yellowGreen")
    static let oliveDrab = Color(name: "oliveDrab")
    static let olive = Color(name: "olive")
    static let darkOliveGreen = Color(name: "darkOliveGreen")
    static let mediumAquamarine = Color(name: "mediumAquamarine")
    static let darkSeaGreen = Color(name: "darkSeaGreen")
    static let lightSeaGreen = Color(name: "lightSeaGreen")
    static let darkCyan = Color(name: "darkCyan")
    static let teal = Color(name: "teal")
    static let coral = Color(name: "coral")
    static let tomato = Color(name: "tomato")
    static let orangeRed = Color(name: "orangeRed")
    static let darkOrange = Color(name: "darkOrange")
    static let orange = Color(name: "orange")
    static let gold = Color(name: "gold")
    static let yellow = Color(name: "yellow")
    static let lightYellow = Color(name: "lightYellow")
    static let lemonChiffon = Color(name: "lemonChiffon")
    static let lightGoldenrodYellow = Color(name: "lightGoldenrodYellow")
    static let papayaWhip = Color(name: "papayaWhip")
    static let moccasin = Color(name: "moccasin")
    static let peachPuff = Color(name: "peachPuff")
    static let paleGoldenrod = Color(name: "paleGoldenrod")
    static let khaki = Color(name: "khaki")
    static let darkKhaki = Color(name: "darkKhaki")
    static let cornsilk = Color(name: "cornsilk")
    static let blanchedAlmond = Color(name: "blanchedAlmond")
    static let bisque = Color(name: "bisque")
    static let navajoWhite = Color(name: "navajoWhite")
    static let wheat = Color(name: "wheat")
    static let burlyWood = Color(name: "burlyWood")
    static let tan = Color(name: "tan")
    static let rosyBrown = Color(name: "rosyBrown")
    static let sandyBrown = Color(name: "sandyBrown")
    static let goldenrod = Color(name: "goldenrod")
    static let darkGoldenrod = Color(name: "darkGoldenrod")
    static let peru = Color(name: "peru")
    static let chocolate = Color(name: "chocolate")
    static let saddleBrown = Color(name: "saddleBrown")
    static let sienna = Color(name: "sienna")
    static let brown = Color(name: "brown")
    static let maroon = Color(name: "maroon")
    static let white = Color(name: "white")
    static let snow = Color(name: "snow")
    static let honeydew = Color(name: "honeydew")
    static let mintCream = Color(name: "mintCream")
    static let azure = Color(name: "azure")
    static let aliceBlue = Color(name: "aliceBlue")
    static let ghostWhite = Color(name: "ghostWhite")
    static let whiteSmoke = Color(name: "whiteSmoke")
    static let seashell = Color(name: "seashell")
    static let beige = Color(name: "beige")
    static let oldLace = Color(name: "oldLace")
    static let floralWhite = Color(name: "floralWhite")
    static let ivory = Color(name: "ivory")
    static let antiqueWhite = Color(name: "antiqueWhite")
    static let linen = Color(name: "linen")
    static let lavenderBlush = Color(name: "lavenderBlush")
    static let mistyRose = Color(name: "mistyRose")
    static let gainsboro = Color(name: "gainsboro")
    static let lightGrey = Color(name: "lightGrey")
    static let silver = Color(name: "silver")
    static let darkGray = Color(name: "darkGray")
    static let gray = Color(name: "gray")
    static let dimGray = Color(name: "dimGray")
    static let lightSlateGray = Color(name: "lightSlateGray")
    static let slateGray = Color(name: "slateGray")
    static let darkSlateGray = Color(name: "darkSlateGray")
    static let black = Color(name: "black")
}
