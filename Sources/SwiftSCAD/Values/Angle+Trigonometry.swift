import Foundation

public func sin(_ angle: Angle) -> Double {
	sin(angle.radians)
}

public func cos(_ angle: Angle) -> Double {
	cos(angle.radians)
}

public func tan(_ angle: Angle) -> Double {
	tan(angle.radians)
}


public func asin(_ value: Double) -> Angle {
	Angle(radians: asin(value))
}

public func acos(_ value: Double) -> Angle {
	Angle(radians: acos(value))
}

public func atan(_ value: Double) -> Angle {
	Angle(radians: atan(value))
}
