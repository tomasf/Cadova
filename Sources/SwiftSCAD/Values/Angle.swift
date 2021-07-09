import Foundation

public struct Angle {
	public let radians: Double

	public init(radians: Double) {
		self.radians = radians
	}

	public init(degrees: Double) {
		self.radians = degrees * .pi / 180.0
	}

	public var degrees: Double {
		radians / (.pi / 180.0)
	}
}

extension Angle: SCADValue {
	public var scadString: String {
		degrees.scadString
	}
}

extension Angle: CustomDebugStringConvertible {
	public var debugDescription: String {
		"\(degrees)°"
	}
}

/*
extension Angle: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
	public typealias IntegerLiteralType = Int
	public typealias FloatLiteralType = Double

	public init(floatLiteral degrees: Double) {
		self.init(degrees: degrees)
	}

	public init(integerLiteral degrees: Int) {
		self.init(degrees: Double(degrees))
	}
}
*/

public func abs(_ angle: Angle) -> Angle {
	Angle(radians: abs(angle.radians))
}
