import Foundation

/// A value representing a geometric angle
public struct Angle {
    /// The angle expressed in radians
	public let radians: Double

    /// Create an angle from radians
	public init(radians: Double) {
		self.radians = radians
	}

    /// Create an angle from degrees
	public init(degrees: Double) {
		self.radians = degrees * .pi / 180.0
	}

    /// The angle expressed in degrees
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
