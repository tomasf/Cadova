import Foundation

public enum Color {
	case components (red: Double, green: Double, blue: Double, alpha: Double)
	case named (Name, alpha: Double)

	public enum Name: String {
		case lavender
		case thistle
		case plum
		case violet
		case orchid
		case fuchsia
		case magenta
		case mediumOrchid
		case mediumPurple
		case blueViolet
		case darkViolet
		case darkOrchid
		case darkMagenta
		case purple
		case indigo
		case darkSlateBlue
		case slateBlue
		case mediumSlateBlue
		case pink
		case lightPink
		case hotPink
		case deepPink
		case mediumVioletRed
		case paleVioletRed
		case aqua
		case cyan
		case lightCyan
		case paleTurquoise
		case aquamarine
		case turquoise
		case mediumTurquoise
		case darkTurquoise
		case cadetBlue
		case steelBlue
		case lightSteelBlue
		case powderBlue
		case lightBlue
		case skyBlue
		case lightSkyBlue
		case deepSkyBlue
		case dodgerBlue
		case cornflowerBlue
		case royalBlue
		case blue
		case mediumBlue
		case darkBlue
		case navy
		case midnightBlue
		case indianRed
		case lightCoral
		case salmon
		case darkSalmon
		case lightSalmon
		case red
		case crimson
		case fireBrick
		case darkRed
		case greenYellow
		case chartreuse
		case lawnGreen
		case lime
		case limeGreen
		case paleGreen
		case lightGreen
		case mediumSpringGreen
		case springGreen
		case mediumSeaGreen
		case seaGreen
		case forestGreen
		case green
		case darkGreen
		case yellowGreen
		case oliveDrab
		case olive
		case darkOliveGreen
		case mediumAquamarine
		case darkSeaGreen
		case lightSeaGreen
		case darkCyan
		case teal
		case coral
		case tomato
		case orangeRed
		case darkOrange
		case orange
		case gold
		case yellow
		case lightYellow
		case lemonChiffon
		case lightGoldenrodYellow
		case papayaWhip
		case moccasin
		case peachPuff
		case paleGoldenrod
		case khaki
		case darkKhaki
		case cornsilk
		case blanchedAlmond
		case bisque
		case navajoWhite
		case wheat
		case burlyWood
		case tan
		case rosyBrown
		case sandyBrown
		case goldenrod
		case darkGoldenrod
		case peru
		case chocolate
		case saddleBrown
		case sienna
		case brown
		case maroon
		case white
		case snow
		case honeydew
		case mintCream
		case azure
		case aliceBlue
		case ghostWhite
		case whiteSmoke
		case seashell
		case beige
		case oldLace
		case floralWhite
		case ivory
		case antiqueWhite
		case linen
		case lavenderBlush
		case mistyRose
		case gainsboro
		case lightGrey
		case silver
		case darkGray
		case gray
		case dimGray
		case lightSlateGray
		case slateGray
		case darkSlateGray
		case black
	}
}


struct Color3D: Geometry3D {
	let color: Color
	let content: Geometry3D

	func scadString(environment: Environment) -> String {
		let params: [String: SCADValue]

		switch color {
		case .components (let red, let green, let blue, let alpha):
			params = ["c": [red, green, blue, alpha]]

		case .named (let name, let alpha):
			params = ["c": name.rawValue, "alpha": alpha]
		}

		return SCADCall(name: "color", params: params, body: content)
			.scadString(environment: environment)

	}
}

extension Geometry3D {
	public func colored(_ name: Color.Name, alpha: Double = 1) -> Geometry3D {
		Color3D(color: .named(name, alpha: alpha), content: self)
	}

	public func colored(red: Double, green: Double, blue: Double, alpha: Double = 1) -> Geometry3D {
		Color3D(color: .components(red: red, green: green, blue: blue, alpha: alpha), content: self)
	}
}
