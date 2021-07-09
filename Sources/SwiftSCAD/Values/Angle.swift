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

public func abs(_ angle: Angle) -> Angle {
	Angle(radians: abs(angle.radians))
}
