import Foundation

postfix operator °

public extension Double {
	static postfix func °(_ a: Double) -> Angle {
		Angle(degrees: a)
	}
}

extension Angle: Comparable {
	public static func +(_ a: Angle, _ b: Angle) -> Angle {
		Angle(radians: a.radians + b.radians)
	}

	public static func -(_ a: Angle, _ b: Angle) -> Angle {
		Angle(radians: a.radians - b.radians)
	}

	public static func *(_ a: Angle, _ b: Double) -> Angle {
		Angle(radians: a.radians * b)
	}

	public static func /(_ a: Angle, _ b: Double) -> Angle {
		Angle(radians: a.radians / b)
	}

	public static func /(_ a: Angle, _ b: Angle) -> Double {
		a.radians / b.radians
	}

	public static func <(_ a: Angle, _ b: Angle) -> Bool {
		a.radians < b.radians
	}

	public static func >(_ a: Angle, _ b: Angle) -> Bool {
		a.radians > b.radians
	}

	public static func ==(_ a: Angle, _ b: Angle) -> Bool {
		a.radians == b.radians
	}

	public static prefix func -(_ a: Angle) -> Angle {
		Angle(radians: -a.radians)
	}
}
