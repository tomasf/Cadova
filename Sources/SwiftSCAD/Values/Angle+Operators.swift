import Foundation

postfix operator °

public extension Double {
    /// Convenience postfix operator for creating an angle from a value in degrees
    ///
    /// ## Example
    /// ```swift
    /// let angle = 45°
    /// ```
	static postfix func °(_ a: Double) -> Angle {
		Angle(degrees: a)
	}
}

extension Angle: Comparable, AdditiveArithmetic {
	public static var zero: Angle {
		0°
	}
	
	public static prefix func -(_ a: Angle) -> Angle {
		Angle(radians: -a.radians)
	}

	public static func +(_ a: Angle, _ b: Angle) -> Angle {
		Angle(radians: a.radians + b.radians)
	}

	public static func -(_ a: Angle, _ b: Angle) -> Angle {
		Angle(radians: a.radians - b.radians)
	}

	public static func *(_ a: Angle, _ b: Double) -> Angle {
		Angle(radians: a.radians * b)
	}

	public static func *(_ a: Double, _ b: Angle) -> Angle {
		Angle(radians: a * b.radians)
	}

	public static func /(_ a: Angle, _ b: Double) -> Angle {
		Angle(radians: a.radians / b)
	}

	public static func /(_ a: Angle, _ b: Angle) -> Double {
		a.radians / b.radians
	}
}

extension Angle {
	public static func <(_ a: Angle, _ b: Angle) -> Bool {
		a.radians < b.radians
	}

	public static func <=(_ a: Angle, _ b: Angle) -> Bool {
		a.radians <= b.radians
	}

	public static func >(_ a: Angle, _ b: Angle) -> Bool {
		a.radians > b.radians
	}

	public static func >=(_ a: Angle, _ b: Angle) -> Bool {
		a.radians >= b.radians
	}

	public static func ==(_ a: Angle, _ b: Angle) -> Bool {
		a.radians == b.radians
	}
}
